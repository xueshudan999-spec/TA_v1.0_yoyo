Shader "Code/PBR"
{
	Properties
	{
		[Toggle]EnableBaseColor("EnableBaseColor",float)=0
		[Toggle]EnableMetallic("EnableMetallic",float)=0
		[Toggle]EnableRoughness("EnableRoughness",float)=0
		[Toggle]EnableEmission("EnableEmission",float)=0
		
		[Space(50)]
		_BaseColor("_BaseColor",color)=(1,1,1,0)
		_Metallic("_Metallic",range(0,1))=0.2
		_Roughness("_Roughness",range(0,1))=0.2
		_Emission("_Emission",color)=(1,1,1,0)
		
		[Space(50)]
		_MainTex("_MainTex",2D)="white"{}
		_MetallicTex("_MetallicTex",2D)="white"{}
		_RoughnessTex("_RoughnessTex",2D)="white"{}
		_EmissionTex("_EmissionTex",2D)="white"{}
		_AO("_AO",2D)="white"{}
		
		_NormalMap("_NormalMap",2D)="bump"{}
		
		[Space(50)]
		[Toggle(ENABLE_BRDF_LUT)]_EnableBrdfLut("_EnableBrdfLut",float)=0
		_BRDFLut("_BRDFLut",2D)="black"{}
	}
	
	SubShader
	{
		Tags { "RenderType"="Opaque" "LightMode"="ForwardBase" }
	LOD 100

		CGINCLUDE
		#pragma target 3.0
		ENDCG
		Blend Off
		AlphaToMask Off
		Cull Back
		ColorMask RGBA
		ZWrite On
		ZTest LEqual
		Offset 0 , 0

		Pass
		{
			Name "Unlit"
			Tags {"RenderType"="Opaque" "LightMode"="ForwardBase" }
			CGPROGRAM

			#ifndef UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX
			//only defining to not throw compilation error over Unity 5.5
			#define UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input)
			#endif
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing
			#pragma multi_compile_fwdbase
			#include "UnityCG.cginc"
			#include "UnityGlobalIllumination.cginc"

			struct MeshData
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float4 color : COLOR;
				float3 normalOS: NORMAL;
				float4 tangentOS: TANGENT;
			};
			
			struct V2FData
			{
				float4 pos : SV_POSITION;
				float4 OSpos : TEXCOORD0;
				float4 WSpos : TEXCOORD1;
				float3 normalOS : TEXCOORD2;
				float3 normalWS : TEXCOORD3;
				float3 tangentOS : TEXCOORD4;
				float3 tangentWS : TEXCOORD5;
				float3 BtangentWS : TEXCOORD6;
				float2 uv : TEXCOORD7;
			};
			
			V2FData vert ( MeshData v )
			{
				V2FData o;
				o.OSpos=v.vertex;
				o.uv=v.uv;
				o.WSpos = mul(unity_ObjectToWorld, v.vertex);
				o.normalOS=v.normalOS;
				o.normalWS=UnityObjectToWorldNormal(v.normalOS);
				o.tangentOS=v.tangentOS;
				o.tangentWS=UnityObjectToWorldDir(v.tangentOS.xyz);
				o.BtangentWS=cross(o.normalWS,o.tangentWS)*v.tangentOS.w;
				o.pos = UnityObjectToClipPos(v.vertex);
				return o;
			}

			#define PI 3.141592654
			#define Epsilon 0.001
			//直接光
			//D
			float D_GGXTR(float3 N,float3 H,float Roughness)
			{
				float a=Roughness;
				float a2=a*a;
				float NH=saturate(dot(N,H));
				float NH2=NH*NH;
				float n=a2/(PI*(NH2*(a2-1)+1)*(NH2*(a2-1)+1));
				return max(n,Epsilon);
			}

			//F
			 float3 F_FresnelSchlick(float NV, float3 F0)
            {
                return F0 + (1.0 - F0) * pow(1.0 - NV, 5);
            }

			//G
			float GeometrySchlickGGX(float NV, float Roughness)
            {
                float r = Roughness + 1.0;
                float k = r * r / 8.0;
                float nominator = NV;
                float denominator = k + (1.0 - k) * NV;
                // return nominator/ max(denominator,0.001) ;//防止分母为0
                return nominator / max(denominator, Epsilon); //防止分母为0
            }

            float G_GeometrySmith(float3 N, float3 V, float3 L, float Roughness)
            {
                float NV = max(dot(N, V), 0);
                float NL = max(dot(N, L), 0);

                float ggx1 = GeometrySchlickGGX(NV, Roughness);
                float ggx2 = GeometrySchlickGGX(NL, Roughness);
                return ggx1 * ggx2;
            }

			//间接光
			//F
			float3 FresnelSchlickRoughness(float NV, float3 F0, float Roughness)
            {
                float s = 1.0 - Roughness;
                return F0 + (max(s.xxx, F0) - F0) * pow(1.0 - NV, 5.0);
            }
			
			//数值近似
			float2 EnvBRDFApprox(float Roughness, float NoV)
            {
                // [ Lazarov 2013, "Getting More Physical in Call of Duty: Black Ops II" ]
                // Adaptation to fit our G term.
                const float4 c0 = {-1, -0.0275, -0.572, 0.022};
                const float4 c1 = {1, 0.0425, 1.04, -0.04};
                float4 r = Roughness * c0 + c1;
                float a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
                float2 AB = float2(-1.04, 1.04) * a004 + r.zw;
                return AB;
            }

			//ACESToneMapping
			float3 ACESToneMapping(float3 x)
            {
                float a = 2.51f;
                float b = 0.03f;
                float c = 2.43f;
                float d = 0.59f;
                float e = 0.14f;
                return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
            }

            float4 ACESToneMapping(float4 x)
            {
                float a = 2.51f;
                float b = 0.03f;
                float c = 2.43f;
                float d = 0.59f;
                float e = 0.14f;
                return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
            }

			sampler2D _NormalMap;
			sampler2D _MainTex;
			sampler2D _MetallicTex;
			sampler2D _RoughnessTex;
			sampler2D _EmissionTex;
			sampler2D _BRDFLut;
			sampler2D _AO;

			float EnableBaseColor;
			float EnableMetallic;
			float EnableRoughness;
			float EnableEmission;

			float4 _BaseColor;
			float4 _Emission;
			float _Metallic;
			float _Roughness;
			
			float4 frag (V2FData i ) : SV_Target
			{
				float3 L=normalize(UnityWorldSpaceLightDir(i.WSpos));
				float3 V=normalize(UnityWorldSpaceViewDir(i.WSpos));
				float3 T=normalize(i.tangentWS);
				float3 N=normalize(i.normalWS);
				float3 B=normalize(i.BtangentWS);
				float2 uv=i.uv;
				float3 H=normalize(L+V);
				
				//normalmap
				float3 normalmap=UnpackNormal(tex2D(_NormalMap,uv));
				float3x3 TBN=float3x3(T,B,N);
				N=mul(normalmap,TBN);

				float NV=saturate(dot(N,V));
				float NL=saturate(dot(N,L));

				float4 Basemap=tex2D(_MainTex,uv);
				float Metallic=tex2D(_MetallicTex,uv).r;
				//float Metallic=0;
				float Roughness=tex2D(_RoughnessTex,uv).r;
				//float Roughness=0.5;
				float4 Emission=tex2D(_EmissionTex,uv);
				float4 AO=tex2D(_AO,uv);

				if(EnableBaseColor) Basemap=_BaseColor;
				if(EnableMetallic) Metallic=_Metallic;
				if(EnableRoughness) Roughness=_Roughness;
				if(EnableEmission) Emission=_Emission;
				
				//直接光
				float3 F0=lerp(0.04,Basemap,Metallic);
				//F
				float3 F=F_FresnelSchlick(NV,F0);
				//D
				float D=D_GGXTR(N,H,Roughness);
				//G
				float G=G_GeometrySmith(N,V,L,Roughness);

				float3 light0=_LightColor0.rgb;
				
				float3 KS=F;   //镜面反射比例
				float3 KD=float3(1,1,1)-KS;   //漫反射比例
				KD*=1-Metallic;

				float3 Diffuse=KD*Basemap;
				//float3 Diffuse=KD*Basemap/PI;
				//float3 Diffuse=KD*Basemap;

				float3 DFG = D * F * G;
                float denominator = max(4 * NV*NL , Epsilon);
                float3 Specular = DFG / denominator;
				//float3 DirectLight=(Diffuse+Specular)*NL*light0;
				float3 DirectLight=(Diffuse+Specular)*NL*light0;
				//return DirectLight.xyzz;
				
				//间接光
				float3 F_InDirectLight=FresnelSchlickRoughness(NV,F0,Roughness);
				float3 Ks=F_InDirectLight;  //间接光的镜面反射比例
				float3 Kd=float3(1,1,1)-Ks;   //间接光的漫反射比例
				Kd*=1-Metallic;
				
				//间接光的漫反射
				float3 InDirectSH=ShadeSH9(float4(N,1));
				float3 InDirectDiffuse=InDirectSH*Basemap*Kd;
				//float3 InDirectDiffuse=InDirectSH*Basemap*Kd/PI;
				//return InDirectSH.xyzz;
				
				//间接光的镜面反射
				float3 R=reflect(-V,N);
				float mip=Roughness*(1.7-0.7*Roughness)*UNITY_SPECCUBE_LOD_STEPS;
				float4 rgb_mip=UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0,R,mip);

				//间接光镜面反射采样的预过滤环境贴图
				float3 EnvSpecularPrefilted=DecodeHDR(rgb_mip,unity_SpecCube0_HDR);

				//
				#ifdef ENABLE_BRDF_LUT
                    //LUT采样
                    float2 env_brdf = tex2D(_BRDFLut, float2(lerp(0, 0.99, NV), lerp(0, 0.99, Roughness))).rg;
                #else
                    //数值近似
                    float2 env_brdf = EnvBRDFApprox(Roughness, NV);
                #endif
				
				//间接光的镜面反射
				float3 InDirectSpecular=EnvSpecularPrefilted*(Ks*env_brdf.r+env_brdf.g);
				float3 InDirectLight=(InDirectSpecular+InDirectDiffuse)*AO;
				float4 FinalLight=(InDirectLight+DirectLight).xyzz;
				return FinalLight;
			}
			ENDCG
		}
	}
}
