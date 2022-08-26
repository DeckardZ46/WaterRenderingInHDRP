Shader "MyShader/OceanShader_01"
{
    Properties 
    {
        // Color
        [Header(Color)]
        _ShallowColor("Shallow Color",Color) = (1,1,1,1)
        _DeepColor("Deep Color",Color) = (1,1,1,1)
        // Normal Texture
        [Header(Normal)]
        _BumpMap("Bump Map", 2D) = "black" {}
        _BumpScale("Bump Scale", Range(0,10)) = 1
        _BumpWeight("Bump Weight", Range(0, 10)) = 1
        // Flow Map
        _FlowMap("Flow Map", 2D) = "black" {}
        _FlowStrength("Flow Strength", Range(-5,5)) = 1
        _FlowSpeed("Flow Speed",Range(0,1)) = 1
        // Foam
        [Header(Foam)]
        _NoiseTex("Noise Texture",2D) = "black"{}
        _FoamColor("Foam Color", Color) = (1,1,1,1)
        _FoamBias("Foam Bias", Range(0,0.5)) = 0
        _FoamIntensity("Foam Intensity",Range(0,1)) = 1
        _FoamDensity("Foam Density",Range(0,0.5)) = 0.2
        // Deep 
        [Header(Depth)]
        _DeepScale("Deep Scale",Range(0,10)) = 1
        _DeepCurve("Deep Curve",Range(0,50)) = 1
        _DeepPower("Deep Power", Range(0,30)) = 1
        // Wave
        [Header(Wave)]
        _WaveParam("WaveParam", Vector) = (0,0,0,0) // xy(direction),z(amplitude),w(wave length)
        _Speed("Speed", Float) = 1
        // Shading
        [Header(Shading)]
        _SpecIntensity("Spec Intensity", Range(0,10)) = 1
        _Shininess("Shininess", Range(0,10)) = 10

        [Enum(Off, 0, Front, 1, Back, 2)]_Cull ("Cull", float) = 2
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

        // Texture Samplers
        TEXTURE2D(_BumpMap);               
        SAMPLER(sampler_BumpMap);
        TEXTURE2D(_FlowMap);               
        SAMPLER(sampler_FlowMap);
        TEXTURE2D(_NoiseTex);               
        SAMPLER(sampler_NoiseTex);

        CBUFFER_START(UnityPerMaterial)
        // Color
        half4 _ShallowColor;
        half4 _DeepColor;

        // Normal Texture
        half4 _BumpMap_ST;
        float _BumpScale;
        float _BumpWeight;
        
        // Flow Map
        half4 _FlowMap_ST;
        float _FlowStrength;
        float _FlowSpeed;

        // Foam
        half4 _NoiseTex_ST;
        half4 _FoamColor;
        float _FoamBias;
        float _FoamIntensity;
        float _FoamDensity;

        // Deep 
        float _DeepScale;
        float _DeepCurve;
        float _DeepPower;

        // Wave
        float4 _WaveParam;
        float _Speed;

        // Shading
        float _SpecIntensity;
        float _Shininess;
        CBUFFER_END

        struct appdata
        {
            float4 positionOS : POSITION;
            float3 normalOS   : NORMAL;
            float4 tangentOS  : TANGENT;
            float2 uv         : TEXCOORD0;
        };

       struct v2f
        {
            float2 uv : TEXCOORD0;
            float3 normalWS : TEXCOORD1;
            float4 positionCS : SV_POSITION;
            float3 positionWS : TEXCOORD2;
            float4 vertexCS: TEXCOORD3;
            float3 normalWSOrigin: TEXCOORD4;
            float4 tangentWS: TEXCOORD5;
        };
        
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
            float3 bitangent = float3(0, 0, 1);
            float3 tangent = float3(1, 0, 0);
            
            // Vertical Movement
            i.positionOS.y += SineWave(_WaveParam, _Time.y * _Speed, i.positionOS.x,  i.positionOS.z, tangent, bitangent);
            
            // origin normal
            o.normalWSOrigin = TransformObjectToWorldNormal(i.normalOS.xyz);

            // Normal
            i.tangentOS.xyz = normalize(tangent);
            i.normalOS = normalize(cross(bitangent, tangent));
            o.normalWSOrigin = TransformObjectToWorldNormal(i.normalOS.xyz);
            o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
            o.vertexCS = o.positionCS;
            o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
            o.normalWS = TransformObjectToWorldNormal(i.normalOS.xyz);
            o.tangentWS = float4(TransformObjectToWorldDir(i.tangentOS.xyz), i.tangentOS.w);
            o.uv = i.uv;
            return o;
        }
        
        float3 FlowUV(float2 uv, float2 flowVector, float time, float phaseOffset = 0)
        {
            float progress = frac(time + phaseOffset);
            float2 resUV;
            float weight = 1 - abs(2 * progress - 1);
            resUV.xy = uv - flowVector * progress;
            return float3(resUV, weight);
        }

        half4 frag(v2f i) : SV_TARGET
        {
            half3 normalWS = normalize(i.normalWS);
            float3 positionWS = i.positionWS;   // do not normalize it
            half3 viewDir = normalize(GetWorldSpaceViewDir(positionWS));
            half3 baseColor = _ShallowColor.rgb;
            float alpha = _ShallowColor.a;
        
            // ------------------------calculate depth------------------------------
            float4 screenPos = ComputeScreenPos(i.vertexCS);
            float2 screenUV = screenPos.xy/i.vertexCS.w;
            
            float3 objectPositionWS = ComputeWorldSpacePosition( screenUV, SampleSceneDepth(screenUV), UNITY_MATRIX_I_VP);
            float waterDeep = abs(positionWS.y - objectPositionWS.y)/max(_DeepScale, 1);
            waterDeep = pow(waterDeep, _DeepPower);
            float deepFactor = 1 - exp2(-_DeepCurve * waterDeep);
           
            baseColor.rgb = lerp(_ShallowColor.rgb, _DeepColor.rgb, deepFactor);
            alpha = saturate(lerp(_ShallowColor.a, _DeepColor.a, deepFactor));

            // ------------------------flow map------------------------------
            float2 bumpUV = i.uv.xy * _BumpMap_ST.xy;
            float2 flowUV = i.uv.xy * _FlowMap_ST.xy + _FlowMap_ST.zw;
            half4 flowMap = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, flowUV) * 2 - 1;
            flowMap.xy *= _FlowStrength;
            float flowTime = _Time.y * _FlowSpeed + flowMap.a;
            float3 uv0 = FlowUV(bumpUV, flowMap.xy, flowTime);
            float3 uv1 = FlowUV(bumpUV, flowMap.xy, flowTime, 0.5);

            // ------------------------normal map------------------------------
            float4 normalTS = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv0.xy)*uv0.z+
            SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv1.xy)*uv1.z;
            normalTS.xyz = normalize(UnpackNormalScale(normalTS,_BumpScale));
            real3x3 tbn = CreateTangentToWorld(normalWS.xyz, normalize(i.tangentWS).xyz, 1);
            
            normalWS = lerp(normalWS, normalize(TransformTangentToWorld(normalTS, tbn)), _BumpWeight);
            normalWS = SafeNormalize(normalWS);

            // ------------------------reflection------------------------------
            
            // ------------------------edge foam------------------------------
            float2 noiseUV = i.uv*_NoiseTex_ST.xy;
            float3 flowNoiseUV0 = FlowUV(noiseUV,flowMap.xy,flowTime);
            float3 flowNoiseUV1 = FlowUV(noiseUV,flowMap.xy,flowTime,0.5);
            float foamNoise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, flowNoiseUV0.xy+_Time.y/150)*flowNoiseUV0.z+
            SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, flowNoiseUV1.xy+_Time.y/50)*flowNoiseUV1.z;

            // ------------------------lighting------------------------------
            Light mainLight = GetMainLight();
            half3 halfVec = normalize(viewDir + mainLight.direction);
            
            half NdotL = dot(normalWS, mainLight.direction);
            half NdotH = dot(normalWS, halfVec);
            half halfLambert = NdotL * 0.5 + 0.5;
            
            half3 diffuse = halfLambert * baseColor.rgb;
            half3 specular = (_SpecIntensity/100) * pow(saturate(NdotH), -_Shininess) * mainLight.color;

            half3 finalColor = specular + diffuse +_FoamColor.rgb * step(deepFactor, _FoamBias/3000)* step(_FoamDensity,foamNoise)*_FoamIntensity;
            return half4(finalColor,alpha);
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

