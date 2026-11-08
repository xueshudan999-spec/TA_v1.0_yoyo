Shader "Code/Card_CG"
{
	Properties
	{
		//边框
		[Space(50)]
		_FrameHint("_FrameHint",Color)=(1,1,1,1)
		_Frame("_Frame",2D)="white"{}
		
		//主体边框
		[Space(50)]
		[HDR]BKHint("BKHint",Color)=(1,1,1,1)
		_BK("_BK",2D)="white"{}
		_Depth0("_Depth0",float)=0
		
		//主体层
		[Space(50)]
		CardHint("CardHint",Color)=(1,1,1,1)
		_Card("_Card",2D)="white"{}
		_Depth("_Depth",float)=0
		
		//背景
		[Space(50)]
		Card2("Card2",2D)="white"{}
		_Depth2("_Depth2",float)=0
		
		//卡牌背面
		[Space(50)]
		_Background("_Background",2D)="black"{}
		
		//噪音
		[Space(50)]
		[HDR]NoiseHint("NoiseHint",Color)=(1,1,1,1)
		Noise("Noise",2D)="white"{}
		_P2NoiseMapVec("_P2NoiseMapVec",vector)=(0,0,0,0)
		
		//彩虹色
		[Space(50)]
		[Toggle]EnableRainBowColor("EnableRainBowColor",float)=0
        _RainbowMap("RainbowMap Map",2D) = "White"{}
	}
	
	SubShader
	{
		Tags { "RenderType"="Opaque" "LightMode"="ForwardBase" "Queue" = "Geometry" }
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
			Cull Off
			Name "Unlit"
			Tags { "RenderType"="Opaque" "LightMode"="ForwardBase" "Queue" = "Geometry" }
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
				float2 uv : TEXCOORD0;
				float3 normalOS: NORMAL;
				float4 tangent: TANGENT;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct V2FData
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 posWS : TEXCOORD1;
				float3 normalWS: TEXCOORD2;
				float3 tangentWS: TEXCOORD3;
				float3 Bitangent: TEXCOORD4;
			};

			V2FData vert ( MeshData v )
			{
				V2FData o;
				o.uv=v.uv;
				o.posWS=mul(unity_ObjectToWorld,v.vertex);
				o.pos=UnityObjectToClipPos(v.vertex);
				o.normalWS=UnityObjectToWorldNormal(v.normalOS);
				o.tangentWS=UnityObjectToWorldDir(v.tangent.xyz);
				o.Bitangent=cross(o.normalWS,o.tangentWS)*v.tangent.w;
				return o;
			}

			sampler2D _Card;
			sampler2D _BK;
			float4 _BK_ST;
			sampler2D _Background;
			sampler2D _Frame;
			sampler2D Card2;
			sampler2D Noise;
			sampler2D _RainbowMap;
			float4 _Card_ST;
			float4 Card2_ST;
			float EnableRainBowColor;
			float _Depth;
			float _Depth0;
			float _Depth2;
			float4 _FrameHint;
			float4 _Frame_ST;
			float4 NoiseHint;
			float4 _RainbowMap_ST;
			float4 CardHint;
			float4 _P2NoiseMapVec;
			float4 BKHint;

			float4 CardIn0(in float Depth,in float2 uv,in float4 _Card_ST,in float3 ViewTS)
			{
				uv=uv*_Card_ST.xy+_Card_ST.zw;
				float3 n=float3(0,0,1);
				float theta=saturate(dot(n,ViewTS));
				float ViewTSLength=Depth/theta;
				float3 startpos=float3(uv,0);
				float3 endpos=startpos+ViewTSLength*ViewTS;
				float4 CardMap=tex2D(_BK,saturate(endpos.xy));
				return CardMap;
			}
			
			float4 CardIn(in float Depth,in float2 uv,in float4 _Card_ST,in float3 ViewTS)
			{
				uv=uv*_Card_ST.xy+_Card_ST.zw;
				float3 n=float3(0,0,1);
				float theta=saturate(dot(n,ViewTS));
				float ViewTSLength=Depth/theta;
				float3 startpos=float3(uv,0);
				float3 endpos=startpos+ViewTSLength*ViewTS;
				float4 CardMap=tex2D(_Card,saturate(endpos.xy));
				return CardMap;
			}

			float4 CardOut(in float Depth,in float2 uv,in float4 _Card_ST,in float3 ViewTS,out float2 CardMapUV)
			{
				uv=uv*_Card_ST.xy+_Card_ST.zw;
				float3 n=float3(0,0,1);
				float theta=saturate(dot(n,ViewTS));
				float ViewTSLength=Depth/theta;
				float3 startpos=float3(uv,0);
				float3 endpos=startpos+ViewTSLength*ViewTS;
				float4 CardMap=tex2D(Card2,saturate(endpos.xy));
				CardMapUV=saturate(endpos.xy);
				return CardMap;
			}

			float3 HsvToRgb(float3 c)
            {
                float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
            }
			
			fixed4 frag (V2FData i ,float backFace:VFace) : SV_Target
			{
				float3 N=normalize(i.normalWS);
				float3 B=normalize(i.Bitangent);
				float3 T=normalize(i.tangentWS);
				float3 L=normalize(UnityWorldSpaceLightDir(i.posWS));
				float3 V=normalize(UnityWorldSpaceViewDir(i.posWS));
				float2 uv=i.uv;

				float3x3 TBN=float3x3(T,B,N);
				float3 ViewTS=mul(TBN,V);

				//1.背面
				if(backFace<0)
				{
					float2 revertUV=float2(1-uv.x,uv.y);
					float4 backmap=tex2D(_Background,revertUV);
					float4 back=backmap;
					 if(EnableRainBowColor)
                    {
                        //反面的法线翻转一下
                        N = -N;
                        float3 H = normalize(V + L *0.2 + V + T*0.3);
                        float nh = saturate( dot(N,H) );

                        float4 rainbow2 = HsvToRgb(float3(uv.y*5.5 + nh*5,1,1)).xyzz;
                        float4 rainbow = tex2D(_RainbowMap,uv*_RainbowMap_ST.xy+_RainbowMap_ST.zw)*2 + rainbow2;
                        
                        float lum = Luminance(backmap);
                        float mask = abs(sin(nh*12*3.1415926)); // 替换了不精确的3.14
                        
                        back = backmap + mask * pow(nh,500) *128*rainbow*lum ;
                    }
                    return back;
				}
			
				// 2.边框
				float4 frame=tex2D(_Frame,uv*_Frame_ST.xy+_Frame_ST.zw);
				frame = frame + ( frame)* _FrameHint*8*pow(abs(sin( uv.y + _Time.y*0.6)),3) *0.5;

				// 主体边框
				float4 BK=CardIn0(_Depth0,uv,_BK_ST,ViewTS);
				BK=BK+BKHint*3*pow(sin( uv.x + _Time.y*0.3),8) *0.5;
				
				float bk1 = 1 - BK.a; 
				
				// Card1
				float4 p1=CardIn(_Depth,uv,_Card_ST,ViewTS)*CardHint;
				p1=lerp(BK,p1,bk1);
				
				// Card2
				float2 p2UV;
				float4 p2=CardOut(_Depth2,uv,Card2_ST,ViewTS,p2UV);

				float noise = tex2D(Noise,p2UV + float2(0,_Time.x*0.5) );
                float noise2 = tex2D(Noise,p2UV.xy + float2(_Time.x*0.5,_Time.x*0.5) );
                
                noise = pow(noise*noise2,_P2NoiseMapVec.x) * _P2NoiseMapVec.y;
                
                p2 = p2 *(noise*NoiseHint*10 * (1-Luminance(p2))) *CardHint;
				
				float4 color=(float4)0;
				color=lerp(p2,p1,p1.a);
				
				color=lerp(color,frame,frame.a);
				return min(10,color);
			}
			ENDCG
		}
	}
	CustomEditor "ASEMaterialInspector"
}
