Shader "MyShader/OceanShader"
{
    Properties
    {

    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }

        LOD 100

        HLSLINCLUDE 

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        
        ENDHLSL
        
        Pass
        {
            HLSLPROGRAM
            
            ENDHLSL
             
        }
    }
}

