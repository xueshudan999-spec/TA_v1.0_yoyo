Shader "Code/NPR"
{
	Properties
	{
		[NoScaleOffset]_BaseMap("_BaseMap",2D)="white"{}
		[NoScaleOffset]_ShadowMap("_ShadowMap",2D)="white"{}
		[NoScaleOffset]_LightMap("_LightMap",2D)="white"{}
		[NoScaleOffset]_LineMap("_LineMap",2D)="black"{} // 战损线条
		[NoScaleOffset]_DecalMap("_DecalMap",2D)="black"{} // 战损线条
		
		_LightThreshold("_LightThreshold",range(0,2))=1
		_DarkSideThreshold("_DarkSideThreshold",range(0,1))=0.5
		_RampOffSet("_RampOffSet",range(-2,2))=0
		_dark("_dark",range(0,1))=0.5

		//贴花
		[Toggle]EnableDecal("EnableDecal",float)=0
		
		//边缘光
		[Space(50)]
		_RimColor("RimColor", Color) = (0.5, 0.7, 1.0, 1) 
		_FresnelIntensity("_FresnelIntensity",float)=1
		_FresnelPow("_FresnelPow",float)=1
		FresnelWidth("FresnelWidth",range(0,1))=1
		
		//高光
		[Space(50)]
		NHWidth("NHWidth",range(0,1))=1
		NHColor("NHColor",color)=(1,1,1,1)
		
		//金属
		[Space(50)]
		_Metallicwidth("_Metallicwidth",range(0,1))=0.5
		_MetallicIntensity("_MetallicIntensity",float)=1
		
		//布料
		[Space(50)]
		_ComWidth("_ComWidth",float)=1
		_ComIntensity("_ComIntensity",float)=1
		
		//轮廓线
		_OutlineScale("_OutlineScale",range(0,1))=1
		_OutlineScale1("_OutlineScale1",range(0,1))=1
		_OutlineColor("_OutlineColor",color)=(1,1,1,1)
		
		//战损线条
		[Space(50)]
		[Toggle]EnableBadLine("EnableBadLine",float)=0
		_BadLineIntensity("_LineIntensity",float)=1
		_BadLinePow("_LinePow",float)=1
	}
	
	SubShader
	{
		Tags { "RenderType"="Opaque" "LightMode"="ForwardBase"}
	LOD 100
		CGINCLUDE
		#pragma target 3.0
		ENDCG
		Blend Off
		AlphaToMask Off
		Cull off
		ColorMask RGBA
		ZWrite On
		ZTest LEqual
		Offset 0 , 0

		Pass
		{
			Name "Unlit"
			Tags { "RenderType"="Opaque"  "LightMode"="ForwardBase" }
			CGPROGRAM
			#ifndef UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX
			#define UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input)
			#endif
			#pragma vertex vert
			#pragma fragment frag
			#pragma shader_feature_local TEST_ON
			#pragma multi_compile_instancing
			#include "UnityCG.cginc"
			struct MeshData
            {
                float4 vertex       : POSITION; //局部坐标
                float2 uv           : TEXCOORD0;//UV
                float4 tangent      : TANGENT;   //切线
                float3 normal       : NORMAL;   //法线
                float4 vertexColor  : Color;    //顶点颜色
            };
            struct VertexToFragmentData
            {
                float4 pos          : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float3 tangent      : TEXCOORD1;
                float3 bitangent    : TEXCOORD2; 
                float3 normal       : TEXCOORD3;
                float3 worldPosition: TEXCOORD4;
                float3 localPosition: TEXCOORD5;
                float3 localNormal  : TEXCOORD6;
                float4 vertexColor  : TEXCOORD7;
            };  
            VertexToFragmentData vert (MeshData v)
            {
                VertexToFragmentData o;
                o.pos           = UnityObjectToClipPos(v.vertex);
                o.uv            = v.uv;
                o.normal        = UnityObjectToWorldNormal(v.normal);
                o.worldPosition = mul(unity_ObjectToWorld,v.vertex);
                o.localPosition = v.vertex.xyz;
                o.tangent       = UnityObjectToWorldDir(v.tangent);
                o.bitangent     = cross(o.normal,o.tangent) * v.tangent.w;
                o.localNormal   = v.normal;
                o.vertexColor   = v.vertexColor;
                return o;
            }

			sampler2D _BaseMap;
			sampler2D _ShadowMap;
			sampler2D _LightMap;
			sampler2D _LineMap;
			sampler2D _DecalMap;
			float _LightThreshold;
			float _DarkSideThreshold;
			float _RampOffSet;
			float Intensity;
			float Pow;
			float _Metallicwidth;
			float _MetallicIntensity;
			float _ComWidth;
			float _ComIntensity;
			float FresnelWidth;
			float EnableBadLine;
			float _FresnelIntensity;
			float _FresnelPow;
			float _dark;
			float DecalIntensity;
			float DecalPow;
			float EnableDecal;
			float4 _RimColor; 
			float NHWidth;
			float4 NHColor;
			
			float4 frag (VertexToFragmentData i ) : SV_Target
			{
				float3 T = normalize(i.tangent);
                float3 N = normalize(i.normal);
                float3 L = normalize( UnityWorldSpaceLightDir(i.worldPosition.xyz));
                float3 V = normalize( UnityWorldSpaceViewDir(i.worldPosition.xyz));
                float3 H = normalize(V+L);
                float4 VertexColor = i.vertexColor;
                float HV = dot(H,V);
                float NV = dot(N,V);
                float NL = dot(N,L);
                float NH = dot(N,H);
				float2 uv=i.uv;
				//贴图
				float4 basemap=tex2D(_BaseMap,uv);
				float4 shadowmap=tex2D(_ShadowMap,uv);
				float4 lightmap=tex2D(_LightMap,uv);
				float4 linemap=tex2D(_LineMap,uv);    //战损线条
				float4 DecalMap=tex2D(_DecalMap,uv);   
				
				//分级
				float MetallicMask=lightmap.r>0.4;    // 金属
				float RampOffsetMask=lightmap.g*2-1;    
				float SpecularIntensityMask=lightmap.b;    //高光
				float InnerLineMask=lightmap.a;    //内勾线
				float ShadowAOMask=i.vertexColor.r;    //常暗纹理线条

				//材质区分
				float LayerMask=shadowmap.a;
				//================ Diffuse ================
				float HalfLambert=NL*0.5+0.5;
				float Threshold=smoothstep(HalfLambert+_RampOffSet+RampOffsetMask,_LightThreshold,0.3)*ShadowAOMask;
				float4 BrightSide=basemap;
				float4 DarkSide=lerp(basemap,basemap*shadowmap,_DarkSideThreshold);
				float4 DarkSideAlpha=lerp(basemap,basemap*shadowmap,_DarkSideThreshold)*basemap.a;
				DarkSide=lerp(DarkSide,DarkSideAlpha,_dark);
				basemap=lerp(DarkSide,BrightSide,Threshold);
				
				//内勾线
				basemap*=InnerLineMask*VertexColor.r;

				//贴花
				if(EnableDecal==1)
				{
					basemap*=DecalMap;
				}
				//战损线条
				if(EnableBadLine==1)
				{
					basemap*=linemap;
				}
				//================ 高光与边缘光计算 ================
				float FresnelMask = pow(step(1-FresnelWidth,1-NV), _FresnelPow) * _FresnelIntensity;
				
				// 2. 基础高光
				float specular = step(1-NHWidth,NH)*Intensity*SpecularIntensityMask*basemap;
				specular += FresnelMask * _RimColor.rgb * (1.0 - Threshold);
				// 4. 金属高光
				if (lightmap.r>0.4)
				{
					specular+=step(1-_Metallicwidth,NV)*_MetallicIntensity*basemap*SpecularIntensityMask;
				}
				// 5. 深色布料/皮革特殊边缘光
				if(LayerMask>0.1)
				{
					basemap=basemap*basemap.a; 
					float comFresnelMask = pow(step(1-_ComWidth,1-NV),0.5) * _ComIntensity;
					specular += comFresnelMask * _RimColor.rgb;
					specular += max(0,specular); // 防止减法出现负色
				}
				if(lightmap.b>0.254)
				{
					specular += step(1-NHWidth,1-NH)*NHColor;
				}
				return basemap + specular;
			}
			ENDCG
		}
		Pass{
            Name "TANGENT"
            Cull Front  
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            struct MeshData
            {
                float4 vertex : POSITION;
                float4 vertexColor : COLOR;
                float4 tangent :TANGENT; 
                float4 normal : NORMAL;
            };
            struct V2FData
            {
                float4 pos : SV_POSITION; 
            };
            float _OutlineScale;
            float _OutlineScale1;
            float4 _OutlineColor;
            V2FData vert(MeshData v)
            {
                V2FData o;
                // 用顶点色的alpha通道控制描边粗细
                v.vertex.xyz += v.tangent.xyz *_OutlineScale*0.01 *v.vertexColor.a ; 
                v.vertex.xyz += v.normal.xyz *_OutlineScale1*0.01 *v.vertexColor.a ; 
                o.pos = UnityObjectToClipPos(v.vertex);
                return o;
            }
            float4 frag(V2FData i) : SV_Target
            {
                return _OutlineColor;
            }
            ENDCG
        }
	}
}
