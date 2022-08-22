Shader "MyShader/OceanShader_01"
{
    Properties 
    {
        // Color
        _ShallowColor("Shallow Color",Color) = (1,1,1,1)
        _DeepColor("Deep Color",Color) = (1,1,1,1)
        // Deep 
        _DeepScale("Deep Scale",float) = 1
        _DeepCurve("Deep Curve",float) = 1
        _DeepPower("Deep Power", Float) = 1
        // Wave
        _WaveParam("WaveParam", Vector) = (0,0,0,0) //xy(direction),zw(amplitude, wave length)
        _Speed("Speed", Float) = 1
        // Shading
        _SpecIntensity("Spec Intensity", Float) = 1
        _Shininess("Shininess", Float) = 10
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
            "Queue"="Transparent"
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
            float4 vertexCS: TEXCOORD3;
            //float4 tangentWS: TEXCOORD5;
        };

        CBUFFER_START(UnityPerMaterial)
        half4 _ShallowColor;
        half4 _DeepColor;

        float _DeepScale;
        float _DeepCurve;
        float _DeepPower;

        float4 _WaveParam;
        float _Speed;

        float _SpecIntensity;
        float _Shininess;
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
        
        v2f vert(appdata i)
        {
            v2f o = (v2f)0;
            float3 bitangent = 0;
            float3 tangent = 0;
            
            
            i.positionOS.y += SineWave(_WaveParam, _Time.y * _Speed, i.positionOS.x,  i.positionOS.z, tangent, bitangent);
            i.tangentOS.xyz = tangent;
            i.normalOS = normalize(cross(bitangent, tangent));
            
            o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
            o.vertexCS = o.positionCS;
            o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
            o.normalWS = TransformObjectToWorldNormal(i.normalOS.xyz);
            
            return o;
        }
        
        half4 frag(v2f i) : SV_TARGET
        {
            half3 normalWS = normalize(i.normalWS);
            float3 positionWS = normalize(i.positionWS);
            half3 viewDir = normalize(GetWorldSpaceViewDir(positionWS));
            // ------------calculate depth---------------
            float4 screenPos = ComputeScreenPos(i.vertexCS);
            float2 screenUV = screenPos.xy/i.vertexCS.w;
            //return half4(screenUV.xy, 0, 1.0);
            float3 objectPositionWS = ComputeWorldSpacePosition( screenUV, SampleSceneDepth(screenUV), UNITY_MATRIX_I_VP);
            float waterDeep = abs(positionWS.y - objectPositionWS.y)/max(_DeepScale, 1);
            waterDeep = pow(waterDeep, _DeepPower);
            float deepFactor = 1 - exp2(-_DeepCurve * waterDeep);

            //deepFactor = clamp(waterDeep,0,1);
           
            half3 baseColor = _ShallowColor.rgb;
            float alpha = 1.0;

            baseColor.rgb = lerp(_ShallowColor.rgb, _DeepColor.rgb, deepFactor);
            alpha = saturate(lerp(_ShallowColor.a, _DeepColor.a, deepFactor));

        
            // Light mainLight = GetMainLight();
            // half3 halfVec = normalize(viewDir + mainLight.direction);
            
            // half NdotL = dot(normalWS, mainLight.direction);
            // half NdotH = dot(normalWS, halfVec);
            // half halfLambert = NdotL * 0.5 + 0.5;
            
            // half3 diffuse = halfLambert * _ShallowColor.rgb;

            // half3 specular = _SpecIntensity * pow(saturate(NdotH), _Shininess) * mainLight.color;

            // half3 finalColor = specular + diffuse;
            return half4(baseColor,alpha);
        }
        
        ENDHLSL
        Pass
        { 
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

