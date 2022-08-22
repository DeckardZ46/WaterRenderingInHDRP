Shader "MyShader/ShowNormal"
{
    Properties 
    {
        _BaseColor("Line Color",Color) = (1,1,1,1)
        _LineLength("Line Length", Float) = 1
        _WaveParam("xy(direction),zw(amplitude, wave length)", Vector) = (0,0,0,0)
        _Speed("Speed", Float) = 1
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
        }
        LOD 100

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"


        struct appdata
        {
            float4 positionOS : POSITION;
            float3 normalOS   : NORMAL;
            float4 tangentOS  : TANGENT;
            float2 uv         : TEXCOORD0;
        };

        struct v2g
        {
            float2 uv : TEXCOORD0;
            float3 normalWS : TEXCOORD1;
            float4 positionCS : SV_POSITION;
            float3 positionWS : TEXCOORD2;
            float4 vertexCS: TEXCOORD3;
            float4 tangentWS: TEXCOORD5;
        };

        struct g2f
        {
            float2 uv : TEXCOORD0;
            float3 normalWS : TEXCOORD1;
            float4 positionCS : SV_POSITION;
            float3 positionWS : TEXCOORD2;
            float4 vertexCS: TEXCOORD3;
            float4 tangentWS: TEXCOORD5;
        };

        CBUFFER_START(UnityPerMaterial)
        half4 _BaseColor;
        float _LineLength;
        float4 _WaveParam;
        float _Speed;
        CBUFFER_END
        
        float SineWave(float4 waveParam, float speed, float x, float z, inout float3 tangent, inout float3 bitangent)
        {
            float amplitude = waveParam.z;
            float waveLength = waveParam.w;
            
            float k = 2 * PI / max(1, waveLength);
            float fx = k * (x - speed);
            float fz = k * (z - speed + 0.5);
            float waveOffset = amplitude * sin(fx) + amplitude * sin(fz);

            tangent = normalize(float3(1, amplitude * k * cos(fx),0));
            bitangent = normalize(float3(0, amplitude * k * cos(fz),1));
            
            return waveOffset;
        }
        
        v2g vert(appdata i)
        {
            v2g o = (v2g)0;

            
            float3 bitangent = 0;
            float3 tangent = 0;
            
            i.positionOS.y += SineWave(_WaveParam, _Time.y * _Speed, i.positionOS.x, i.positionOS.z, tangent, bitangent);
            i.tangentOS.xyz = tangent;
            i.normalOS = normalize(cross(bitangent, tangent));
            
            o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
            o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
            o.normalWS = TransformObjectToWorldNormal(i.normalOS.xyz);
            
            return o;
        }


        [maxvertexcount(4)]
        void geom(point v2g i[1], inout LineStream<g2f> lineStream)
        {
            v2g input = i[0];
            g2f o0 = (g2f)0;
            
            o0.positionCS = input.positionCS;
            lineStream.Append(o0);

            
            g2f o1 = (g2f)0;
            o1.positionWS = input.positionWS + input.normalWS * _LineLength;
            o1.positionCS = TransformWorldToHClip(o1.positionWS);
            lineStream.Append(o1);
        }
        
        half4 frag(g2f i) : SV_TARGET
        {
            return half4(_BaseColor.rgb,1);
        }
        
        ENDHLSL
        Pass
        {

            Tags 
            {
                "LightMode" = "SRPDefaultUnlit"
            }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geom
            ENDHLSL
        }
    }
}