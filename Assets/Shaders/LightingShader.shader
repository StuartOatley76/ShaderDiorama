Shader "Stuart/LightingShader"
{
    Properties
    {
        //Whether to use a texture or a colour
        [Toggle(USETEXTURE)] useTexture("Use texture", float) = 0

        //The texture
        _MainTex ("Texture", 2D) = "white" {}

        //The colour
        colour("Colour", Color) = (1, 1, 1, 1)

        //Whether to use a smoothness map or the gloss value
        [Toggle(USESMOOTHMAP)] useSmoothnessMap("Use smoothness map", float) = 0

        //The smoothness map
        smoothMap("Smoothness map", 2D) = "white" {}

        //The gloss value
        gloss("Glossiness", range(0, 1)) = 0
        
        //Whether this material is metallic
        [Toggle(METALLIC)] isMetallic("Is metallic", float) = 0

        //Whether this material has a normal map
        [Toggle(USENORMALMAP)] useNormalMap("use normal map", float) = 0

        //The normal map
        normalMap("Normal map", 2D) = "white" {}
    }
    SubShader
    {
        Tags 
        { 
            "RenderType"="Opaque" 
            "RenderPipeline" = "UniversalPipeline"
        }
        LOD 100
        Cull Off

        //Lighting pass
        Pass
        {

            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            //Sets the functions that act as the vertex and fragment shaders
            #pragma vertex vert
            #pragma fragment frag

            //Multi compile definitions required for lighting by Unity
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT

            //Multi compile definitions for toggles in material property
            #pragma multi_compile __ USESMOOTHMAP
            #pragma multi_compile __ METALLIC
            #pragma multi_compile __ USENORMALMAP
            #pragma multi_compile __ USETEXTURE
            
            #include "Lighting.hlsl"
            
            //Definitions for properties
            CBUFFER_START(UnityPerMaterial)
                sampler2D _MainTex;
                float4 _MainTex_ST;
                float4 colour;
                float gloss;
                sampler2D smoothMap;
                sampler2D normalMap;
            CBUFFER_END

            //Data recieved by the vertex shader
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            //Data recieved by the fragment shader
            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 vertexCP : SV_POSITION;
                float3 vertexWP : TEXCOORD1;
            };  

            //Vertex shader - Transforms values ready for use in the fragment shader
            v2f vert (appdata v)
            {
                v2f o;
                o.vertexCP = TransformObjectToHClip(v.vertex.xyz);
                o.vertexWP = TransformObjectToWorld(v.vertex.xyz);
                o.normal = TransformObjectToWorldNormal(v.normal);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            //Fragment shader - applies toggles then passes data to the GetLambertBlinnPhongForAllLights function in Lighting.hlsl
            float4 frag (v2f i) : SV_Target
            {

                float4 col;

                #if defined(USETEXTURE)
                    col = tex2D(_MainTex, i.uv);
                #else
                    col = colour;
                #endif

                float smooth;
                #if defined(USESMOOTHMAP)
                    smooth = tex2D(smoothMap, i.uv).w;
                #else
                    smooth = gloss;
                #endif
                smooth = gloss;
                 #if defined(USENORMALMAP)
                     i.normal = TransformObjectToWorldNormal(tex2D(normalMap, i.uv).xyz);
                 #endif

                float4 lighting = GetLambertBlinnPhongForAllLights(col, i.vertexWP, i.normal, smooth);

                return GetAmbientLight(col) + lighting;
            }
            ENDHLSL
        }

        //ShadowMap pass - Sets vert and fragment shader from shadows.hlsl
        Pass
        {

            Tags { "LightMode" = "ShadowCaster" }

            HLSLPROGRAM

                #pragma vertex shadowVert
                #pragma fragment shadowFrag

                #include "Shadows.hlsl"

            ENDHLSL
        }
    }
}
