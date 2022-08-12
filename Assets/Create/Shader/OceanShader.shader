Shader "MyShader/OceanShader"
{
    Properties 
    {
        _BaseColor("Base Color",Color) = (1,1,1,1)
        _WaveParam("WaveParam", Vector) = (0,0,0,0) //xy(direction),zw(amplitude, wave length)
        _Speed("Speed", Float) = 1
        _SpecIntensity("Spec Intensity", Float) = 1
        _Shininess("Shininess", Float) = 10
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
        }
        LOD 100

        HLSLINCLUDE
        #include "./Gerstner.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


        struct appdata
        {
            float4 positionOS : POSITION;
            float3 normalOS   : NORMAL;
            float4 tangentOS  : TANGENT;
            float2 uv         : TEXCOORD0;
        };

       struct v2f
        {
            //float2 uv : TEXCOORD0;
            float3 normalWS : TEXCOORD1;
            float4 positionCS : SV_POSITION;
            float3 positionWS : TEXCOORD2;
            //float4 vertexCS: TEXCOORD3;
            //float4 tangentWS: TEXCOORD5;
        };

        CBUFFER_START(UnityPerMaterial)
        half4 _BaseColor;
        float4 _WaveParam;
        float _Speed;
        float _SpecIntensity;
        float _Shininess;
        CBUFFER_END
        
         float SineWave(float4 waveParam, float speed, float x)
        {
            float amplitude = waveParam.x;
            float waveLength = waveParam.y;
            float k = 2 * PI / max(1, waveLength);
            float waveOffset = amplitude * sin(k * (x - speed));
            return waveOffset;
        }
        
        v2f vert(appdata i)
        {
            v2f o = (v2f)0;
            i.positionOS.y += SineWave(_WaveParam, _Time.y * _Speed, i.positionOS.x);
            i.positionOS.y += SineWave(_WaveParam, _Time.y * _Speed + 0.5, i.positionOS.z);
            o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
            
            return o;
        }
        
        half4 frag(v2f i) : SV_TARGET
        {
           return half4(1,1,1,1);
        }
        
        ENDHLSL
        Pass
        {

            Tags 
            {
                "LightMode" = "SRPDefaultUnlit"
                "Queue" = "Transparent"
            }
            
            Cull[_Cull]
            BlendOp Add
            Blend SrcAlpha OneMinusSrcAlpha 
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            //#pragma geometry geom
            ENDHLSL
        }
    }
}

