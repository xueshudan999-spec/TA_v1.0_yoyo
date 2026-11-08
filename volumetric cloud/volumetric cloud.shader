Shader "Code/volumetric cloud"
{
	Properties
	{
		_Scale("Scale",float)=1
		_3DTex("_3DTex",3D)="white"{}
		_3DScale("_3DScale",float)=1
		[Enum(Red, 0, Green, 1, Blue, 2, Alpha, 3)] NoiseEnum("NoiseEnum", Float) = 0
		
		[Space(50)]
		AmbientColor1("AmbientColor1",color)=(1,1,1,1)
		AmbientColor2("AmbientColor2",color)=(1,1,1,1)
		DensityNum("DensityNum",range(0,1))=0
		
		[Space(50)]
		_3DMeshTexture("_3DMeshTexture",3D)="black"{}
		_NoiseIntensity("_NoiseIntensity",float)=1
	}
	
	SubShader
	{
		Tags { "Queue"="Transparent" "RenderType"="Transparent" }
	LOD 100
		Cull Front
		Blend OneMinusSrcAlpha SrcAlpha
		Pass
		{
			CGPROGRAM
			#ifndef UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX
			#define UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input)
			#endif
			#pragma target 3.0 
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
			#include "UnityLightingCommon.cginc"

         struct cpu2vs
         {
            float4 vertex : POSITION;
            float4 color  : COLOR;
            float2 uv     : TEXCOORD0;
            float2 uv1    : TEXCOORD1;
            float4 worldPos:TEXCOORD3;
            float3 ObjectNormal : NORMAL;
         };
         struct vs2ps
         {
            float4 vertex : SV_POSITION;
            float2 uv     : TEXCOORD0;
            float2 uv1    : TEXCOORD1;
            float4 ObjectPos:TEXCOORD2;
            float4 worldPos:TEXCOORD3;
            float3 ObjectNormal : TEXCOORD4;
            float3 WorldNormal:TEXCOORD5; 
         };

         sampler2D _MainTex;
			
         vs2ps vert ( cpu2vs v )
         {
             vs2ps o;
            o.vertex = UnityObjectToClipPos(v.vertex);
            o.uv=v.uv;
            o.uv1=v.uv1;
            o.worldPos=mul(unity_ObjectToWorld,v.vertex);
            o.ObjectPos=v.vertex;
            o.ObjectNormal=v.ObjectNormal;
            o.WorldNormal=UnityObjectToWorldNormal(v.ObjectNormal); 
            return o;
         }

			float SDSphere(float3 p,float r)
         {
	         return length(p)-r;
         }
			
			float sdTorus(float3 p,float2 t)
         {
	         float2 q =float2(length(p.xz)-t.x,p.y);
         	 //float2 q = float2(length(p.yz) - t.x, p.x);
	         return length(q)-t.y;
         }
			
			float opSmoothUnion(float d1, float d2, float k)
		{
		    float h = max(k - abs(d1 - d2), 0.0);
		    return min(d1, d2) - h * h * 0.25 / k;
		}
			
			float opSmoothSubtraction(float d1, float d2, float k)
		{
		    return -opSmoothUnion(d1, -d2, k);
		}

			float opSubtraction(float d1, float d2)
		{
		    return max(-d1, d2);
		}
			
			float map(float3 pos)
         {
	        float sphere1=SDSphere(pos+float3(0,(sin(_Time.y*1.5))*0.2,0),0.2); //小球
	        float sphere2=SDSphere(pos+float3((sin(_Time.y*1.8))*0.4,0,0),0.25);  //大球
         	float Torus=sdTorus(pos,float2(0.32,0.08));  //圆环
         	float sdf=min(sphere1,sphere2);
         	sdf=opSmoothUnion(sphere1,sphere2,0.01);
         	sdf=opSmoothUnion(sdf,Torus,0.1);
         	return sdf;
         }

			//射线与AABB求交
		bool intersectAABB(float3 rayOrigin, float3 rayDir, float3 boxMin,
        float3 boxMax,out float2 tNearFar)
		{
		    float3 tMin = (boxMin - rayOrigin) / rayDir;
		    float3 tMax = (boxMax - rayOrigin) / rayDir;
		    float3 t1 = min(tMin, tMax);
		    float3 t2 = max(tMin, tMax);
		    float tNear = max(max(t1.x, t1.y), t1.z);
		    float tFar = min(min(t2.x, t2.y), t2.z);
		    tNearFar = float2(tNear, tFar);
		    
		    return tFar>tNear;
		}

		float3 calcNormal(in float3 pos)
        {
            float3 eps = float3(0.005, 0.0, 0.0);
            return normalize(float3(
                map(pos + eps.xyy).x - map(pos - eps.xyy).x,
                map(pos + eps.yxy).x - map(pos - eps.yxy).x,
                map(pos + eps.yyx).x - map(pos - eps.yyx).x));
        }
			
		//阴影
		 float calcHardShadow(float3 ro, float3 rd, float mint, float maxt)
        {
            float t = mint;
            for (int i = 0; i < 256 && t < maxt; i++)
            {
                float h = map(ro + rd * t);
                if (h < 0.001)
                    return 0.0;
                t += h;
            }
            return 1.0;
        }

		//软阴影
		float calcSoftShadow(float3 ro, float3 rd, float mint, float maxt, float k)
        {
            float res = 1.0;
            float t = mint;
            for (int i = 0; i < 256 && t < maxt; i++)
            {
                float h = map(ro + rd * t);
                if (h < 0.001)
                    return 0.0;
                res = min(res, k * h / t);
                t += h;
            }
            return res;
        }

		#define _G0 -0.1
		#define _G1 0.1
		#define _BackForwardLerp 0.7
		// Henyey-Greenstein 相函数
	    // 夹角余弦，相函数参数值
	    float hg(float a, float g) 
	    {
	        float g2 = g * g;
	        return (1 - g2) / (4 * 3.1415 * pow(1 + g2 - 2 * g * (a), 1.5));
	    }
	    float hg2(float a)    //传入的是光线与视线的点积
	    {
	        return lerp(hg(a, _G0), hg(a, _G1), _BackForwardLerp);
	    }
			
		float HenyeyGreenstein(float g, float costh)
        {
            return (1.0 / (4.0 * 3.1415))  * ((1.0 - g * g) / pow(1.0 + g*g - 2.0*g*costh, 1.5));
        }
        // 模拟多次散射的效果
        float multipleOctaves(float depth, float mu)
        {
            float3 luminance = 0;
            int octaves = 8;
            float a = 0.5;
            float b = 0.5;
            float c = 0.5;
            float phase;

            for (int i = 0; i < octaves; ++i)
            {
                phase = lerp(HenyeyGreenstein(mu, -0.1 * c), HenyeyGreenstein(mu, 0.3 * c), 0.7);
                luminance += b * phase * exp(-depth * a*float3(0.5, 1.0, 1.0));
                a *= 0.2f;
                b *= 0.5f;
                c *= 0.5f;
            }
            return luminance;
        }
			
			#define MAX_RAYMARCHING_STEP 32
			#define MAX_LIGHT_RAYMARCHING_STEP 64
			#define MIN_SDF 0.001
			float _Scale;
			float _3DScale;
			sampler3D _3DTex;
			sampler3D _3DMeshTexture;
			float NoiseEnum;
			float4 AmbientColor1;
			float4 AmbientColor2;
			float DensityNum;
			float _NoiseIntensity;

		float remap(float x, float low1, float high1, float low2, float high2)
	    {
	        return low2 + (x - low1) * (high2 - low2) / (high1 - low1);
	    }

		float Cloud(float3 pos,out float sdf,out float noise)
		{
			float sphere1=SDSphere(pos+float3((sin(_Time.y*1.5))*0.2,0,0),0.2);
			sdf=tex3D(_3DMeshTexture,pos+0.5);
			if(sdf>0)
			{
				return 0;
			}
		    noise = tex3D(_3DTex, frac(pos*_3DScale)+_Time.y*0.2)[NoiseEnum];
			float density=saturate(remap(sdf,noise*_NoiseIntensity,1,0,1));
			return density;
		}

		float4 RayMarching(float3 rayPos, float3 rayDir)
		{
			float3 L = normalize(mul(unity_WorldToObject, float4(_WorldSpaceLightPos0.xyz, 0)).xyz);
			float costheta=dot(L,rayDir);
			float HG2=hg2(costheta);
		    float2 tNearFar;
		    // 1. 包围盒求交
		    bool isHit = intersectAABB(rayPos, rayDir, float3(-0.5, -0.5, -0.5), float3(0.5, 0.5, 0.5), tNearFar);
		    if (!isHit)
		    {
		        discard;
		        return 0;
		    }
		    // 计算包围盒内的步进参数
		    float tNear = max(0.0f, tNearFar.x);
		    float tFar = tNearFar.y;
		    // 射线在盒子内部能走的最大距离
		    float maxDistance = tFar - tNear; 
		    
		    // 起点位置（进入盒子的位置）
		    float3 startPos = rayPos + tNear * rayDir;

			float3 pos=startPos;

			//光线均匀步进（介质是均匀的）
			/*
			 float step=0.01;
         	float distance=0.0f;
         	for(int i=0;i<MAX_RAYMARCHING_STEP;i++)
         	{
         		pos+=step*rayDir;
         		distance+=step;
         		if(distance>maxDistance) break;
         	}
				float alpha=1-exp(-distance*_Scale);
         	//return alpha;
         	return float4(0.3, 0.5, 1, alpha);
			 */

			//非均匀介质光线步进    ——密度(intensity,Density )
			
         	float distance=0.0f;
         	float optiondis=0.0f;
			float a=1;
			float4 FinalColor=float4(0,0,0,a);
			
			UNITY_LOOP
         	for(int i=0;i<MAX_RAYMARCHING_STEP;i++)
         	{
         		float step=0.01;
         		float sdfDensity=0,noiseDensity=0;
				float intensity=Cloud(pos,sdfDensity,noiseDensity);

         		//以下两行代码实现的效果是使得光线步进直接跳过sdf>0的部分
         		float currentStep = max(sdfDensity, step);
				distance += currentStep;
         		
         		pos=startPos+distance*rayDir;
         		optiondis+=intensity*step;
         		
				//光照强度     ——光照强度（LightEnergy，Lightintensity）
         		if(sdfDensity<0&&intensity > 0.01)
				{
				    float Lightstep = 0.01;
				    float Lightoptiondis = 0.0f;
				    float3 LightPos = pos;
				    
				    UNITY_LOOP
				    for(int j=0; j<MAX_LIGHT_RAYMARCHING_STEP; j++)
				    {
				        LightPos += L * Lightstep; // 先步进
				    	float sdfLight,noiseLight;
				        float Lightintensity = Cloud(LightPos,sdfLight,noiseLight); // 采样光源位置的密度
				    	Lightoptiondis += Lightintensity * Lightstep;
				        if(any(LightPos < (float3)-0.5) || any(LightPos > (float3)0.5)) break;
				    }
				    // 1. 光源方向的透射率
				    //float LightEnergy = exp(-Lightoptiondis * _Scale);
         			float3 LightEnergy = 20*_LightColor0.rgb* multipleOctaves(Lightoptiondis, costheta) * 3.14 *HG2*8 ;
				    // 2. 当前这一步的局部透射率
				    float localTransmittance = exp(-intensity * step * _Scale);
         			//增加环境光(这里的环境光是由普通的环境光和密度影响两部分组成的)
				    float3 Ambient=lerp(AmbientColor1,AmbientColor2,pos.y+0.5)*lerp(1,localTransmittance,DensityNum);
					float3 CurrentColor=Ambient+LightEnergy;
         			// 3. 前向累加颜色
				    FinalColor.rgb += (1.0 - localTransmittance) * CurrentColor * FinalColor.a;
				    // 4. 累乘视线透射率
				    FinalColor.a *= localTransmittance;
				}
         			if(FinalColor.a<0.01)break;
         			if(distance>maxDistance) break;
         	}
         	return FinalColor;
		}

			float4 frag (vs2ps i ) : SV_Target
			{
				float3 camPos=mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1));
				float3 rayPos=camPos;
				float3 rayDir=normalize(i.ObjectPos-camPos);
				float4 Final=RayMarching(rayPos,rayDir);
				return Final;
			}
			ENDCG
		}
	}
}
