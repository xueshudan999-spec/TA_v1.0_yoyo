Shader "MyGlitch"
{
	Properties
	{
		_MainTex("_MainTex",2D)="black"{}
		_Noise("_Noise",2D)="white"{}
		_Mask("_Mask",2D)="white"{}
		
		[Space(20)]
		GlitchSpeed("GlitchSpeed",float)=2
		GlitchIntensity("GlitchIntensity",float)=5
		_Move("_Move",float)=0
		
		[Space(20)]
		Fresnel_Bias("Fresnel_Bias",float)=0
		Fresnel_Scale("Fresnel_Scale",float)=0
		Fresnel_Power("Fresnel_Power",float)=0
		
		[Space(20)]
		[Toggle]EnableDir("EnableDir",float)=1
		[Toggle]_X("_X",float)=1
		[Toggle]_Y("_Y",float)=0
		[Toggle]_Z("_Z",float)=0
		
		[Space(20)]
		[Toggle]EnableCol("EnableCol",float)=1
		_Dir1Col("_Dir1Col",color)=(1,1,0,0)
		_Dir2Col("_Dir2Col",color)=(0,1,1,0)
	}
	
	SubShader
	{
		Tags { "RenderType"="Opaque" }
	LOD 100

		CGINCLUDE
		#pragma target 3.0
		ENDCG
		AlphaToMask Off
		Cull Back
		ColorMask RGBA
		ZWrite On
		ZTest LEqual
		Offset 0 , 0

		Pass
		{
			Name "Unlit"
			Tags { "LightMode"="ForwardBase" }
			CGPROGRAM

			#ifndef UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX
			#define UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input)
			#endif
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing
			#include "UnityCG.cginc"

			struct MeshData
			{
				float4 vertex : POSITION;
				float2 uv    : TEXCOORD0;
				float3 OSnormal : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct V2FData
			{
				float4 OSpos : SV_POSITION;
				float2 uv     : TEXCOORD0;
				float4 WSpos : TEXCOORD2;
				float3 OSnormal : TEXCOORD3;
				float3 WSnormal : TEXCOORD4;
				
			};

			float GlitchSpeed;
			sampler2D _MainTex;
			sampler2D _Mask;
			sampler2D _Noise;
			float4 _Mask_ST;
			float4 _Noise_ST;
			float EnableCol;
			float4 _Dir1Col;
			float4 _Dir2Col;
			float _X;
			float _Y;
			float _Z;
			float _Move;
			float GlitchIntensity;
			float Fresnel_Bias;
			float Fresnel_Scale;
			float Fresnel_Power;

			float4 GlitchNoise(float2 coord)
            {
                float4 c = float4(coord, 0, 1);
                float4 d=0;
                float4 e;
                for (int j = 16; j > 0; j--)
                {
                    e = floor(c);
                    d += sin(e * e.yxyx + e * (_Time / 10));
                    c *= 2.5;
                }
                float4 glitch_res = d;
                return glitch_res;
            }
			
			float3 HSVToRGB( float3 c )
			{
				float4 K = float4( 1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0 );
				float3 p = abs( frac( c.xxx + K.xyz ) * 6.0 - K.www );
				return c.z * lerp( K.xxx, saturate( p - K.xxx ), c.y );
			}
			
			float4 GetMask(float2 uv)
			{
				float speedtime=GlitchSpeed*_Time.x*30;
				float offset_sin=sin(speedtime*2)+1;
				float offset_cos=cos(speedtime*2);

				float4 mask=tex2Dlod(_Mask,float4(uv*float2(_Mask_ST.x,_Mask_ST.y*offset_cos)+float2(_Mask_ST.z,_Mask_ST.w*offset_sin),0,0));
				return mask;
			}
			
			V2FData vert ( MeshData v )
			{
				V2FData o;
				float4 Mask=GetMask(v.uv);
				float4 Glitchnoise=GlitchNoise(v.uv)*Mask.x;
				float3 Direction=float3(_X,_Y,_Z);
				float phase = frac(_Time.y / 4);
				float active = step(phase, 0.5);       
				float localPhase = phase * 2.0;         
				float animWeight = active * sin(localPhase * 6.28318);
				o.WSnormal=UnityObjectToWorldNormal(v.OSnormal);
				v.vertex.xyz += Glitchnoise.xyz * o.WSnormal.xyz * Direction * _Move * 10 * animWeight;
				o.WSpos=mul(unity_ObjectToWorld,v.vertex);
				o.OSpos=UnityObjectToClipPos(v.vertex);
				o.uv=v.uv;
				o.OSnormal=v.OSnormal;
				return o;
			}
			
			fixed4 frag (V2FData i ) : SV_Target
			{
				float speedtime=GlitchSpeed*_Time.x*30;
				float4 BaseMap=tex2D(_MainTex,i.uv);
				float4 Mask=tex2D(_Mask,i.uv);
				float4 Noise=tex2Dlod(_Noise,float4(i.uv*_Noise_ST.xy,_Noise_ST.zw*speedtime));
				
				float MaskNoise=Mask.x*Noise.x;
				float2 distortUV=i.uv+MaskNoise*GlitchIntensity*i.uv.x*saturate(sin(speedtime));
				float4 glitchnoise=GlitchNoise(distortUV);

				float4 glitchColor=(float4)0;
				if(EnableCol==1)
				{
					float3 cameraNormal=mul((float3x3)unity_WorldToCamera,i.WSnormal);
					glitchColor=lerp(_Dir1Col,_Dir2Col,cameraNormal.x*0.5+0.5);
				}
				else
				{
					glitchColor=HSVToRGB(float3(frac(i.WSpos.x),1,0.5)).xyzz;
				}

				glitchColor.r+=MaskNoise*glitchnoise.x*saturate(sin(speedtime))*GlitchIntensity*0.32;
				glitchColor.g+=MaskNoise*glitchnoise.y*saturate(sin(speedtime*2))*GlitchIntensity*0.65;
				glitchColor.b+=MaskNoise*glitchnoise.x*saturate(sin(speedtime*3))*GlitchIntensity*0.86;

				float3 V=normalize(i.WSpos.xyz-_WorldSpaceCameraPos.xyz);
				float NV=saturate(dot(i.WSnormal,V)+Fresnel_Bias);
				float Fresnel=Fresnel_Scale*pow(NV,Fresnel_Power);
				return lerp(BaseMap,glitchColor,Fresnel);
			}
			ENDCG
		}
	}
}
