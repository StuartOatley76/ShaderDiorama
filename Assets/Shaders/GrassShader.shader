Shader "Stuart/GrassShader"
{
    Properties
    {
        //Colour at the bottom of the blade of grass
        bottomColour("Bottom Colour", Color) = (1, 1, 1, 1)

        //Colour at the top of the blade
        topColour("Top Colour", Color) = (1, 1, 1, 1)

        //Texture for the blade of brass
        bladeTexture("Blade texture", 2D) = "white" {}
        
        //Mins and maxes for blade size
        minWidth("Minimum blade width", Range(0, 0.1)) = 0.025
        maxWidth("Maximum blade width", Range(0, 0.1)) = 0.05
        minHeight("Minimum blade height", Range(0, 2)) = 0.1
        maxHeight("Maximum blade height", Range(0, 2)) = 0.2

        //Amount a blade can bend forwards
        bladeBendAmount("Blade bend", Float) = 0.38

        //Amount a blade can curve
        bladeCurve("Blade curve amount", Range(1, 4)) = 2

        //how much varience there is in the amount blandes bend
        bendVarience("Bend varience", Range(0, 1)) = 0.2

        tessellationUniform("Grass Density", Range(1, 64)) = 1

        //Noise map for wind
        windMap("Wind Offset Map", 2D) = "bump" {}

        //Wind Velocity
        windStrength("Wind Strength", float) = 1

        //How often the wind blows
        windFrequency("Wind Frequency", Vector) = (0.05, 0.05, 0, 0)
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
            "RenderPipeline" = "UniversalPipeline"
        }
        LOD 100
        Cull Off

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "HLSLTessellation.hlsl"
        #include "CGMaths.cginc"

        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
        #pragma multi_compile _ _SHADOWS_SOFT

        #define BLADE_SEGMENTS 4

        //Struct for data used in the Geometry pass
        struct GeometryData
        {
            float4 position : SV_POSITION;
            float3 normal : NORMAL;
            float2 uv : TEXCOORD0;
            float3 worldPos : TEXCOORD1;
        };

        //Constant buffer to hold property values
        CBUFFER_START(UnityPerMaterial)
            float4 bottomColour;
            float4 topColour;
            sampler2D bladeTexture;

            float minWidth;
            float maxWidth;
            float minHeight;
            float maxHeight;

            float bladeBendAmount;
            float bladeCurve;

            float bendVarience;

            sampler2D windMap;
            float4 windMap_ST;
            float  windStrength;
            float4 windFrequency;
        CBUFFER_END

        //Creates a GeometryData at the position given applying the supplied offset and transformation matrix
        GeometryData CreateTransformedGeometryData(float3 pos, float3 offset, float3x3 transformationMatrix, float2 uv)
        {
            float3 localPos = pos + mul(transformationMatrix, offset);
            float3 tangentNormal = normalize(float3(0, -1, offset.y));
            float3 localNormal = mul(transformationMatrix, tangentNormal);

            GeometryData data;
            data.position = TransformObjectToHClip(localPos);
            data.normal = TransformObjectToWorldNormal(localNormal);
            data.uv = uv;
            data.worldPos = TransformObjectToWorld(pos + mul(transformationMatrix, offset));

            return data;
        }

        //The Geometry Shader. Creates a blade of grass at each vertex 
        [maxvertexcount(BLADE_SEGMENTS * 2 + 1)] //One vertex for each side of the segment and one for the top
        void GShader(point VertexOut input[1], inout TriangleStream<GeometryData> triStream)
        {
            //Get position, normal, tangent and bitangent
            float3 pos = input[0].vertex.xyz;
            float3 normal = input[0].normal;
            float4 tangent = input[0].tangent;
            float3 bitangent = cross(normal, tangent.xyz) * tangent.w;

            //Create matrix to convert from tangent space to local
            float3x3 tangentToLocalSpace = float3x3
                (
                    tangent.x, bitangent.x, normal.x,
                    tangent.y, bitangent.y, normal.y,
                    tangent.z, bitangent.z, normal.z
                    );

            //Get matrix to rotate around the Y axis a random amount
            float3x3 randomRotation = GetRotationMatrix(rand(pos) * S_TWO_PI, float3(0, 0, 1.0f));

            //Get Matrix to rotate arounnd the bottom of the blade (bend the blade)
            float3x3 randomBend = GetRotationMatrix(rand(pos.zyx) * S_PI * 0.5f * bendVarience, float3(-1.0f, 0, 0));

            //Any texture (eg windMap) with an _ST after the name, unity provides a float4 for. xy contains the scale and zw contains the offset
            //So we create a UV by multiplying the position's xz by the windmap's scale then adding the offset and multiplying by the frequency and time
            float2 uv = pos.xz * windMap_ST.xy + windMap_ST.zw + windFrequency * _Time.y;

            // Sample the wind distortion map, and construct a normalized vector of its direction.
            float2 windSample = (tex2Dlod(windMap, float4(uv, 0, 0)).xy * 2 - 1) * windStrength;

            //Get the axis the wind is blowing around (z = 0 as mind doesn't blow up or down. Why? Game logic ;))
            float3 wind = normalize(float3(windSample.x, windSample.y, 0));

            //Get the rotation matrix of the wind
            float3x3 windRotation = GetRotationMatrix(S_PI * windSample, wind);

            //Multiply the tangent to local matrix by the random rotation matrix to give the transformation matrix for the base of the blade
            float3x3 baseTransformationMatrix = mul(tangentToLocalSpace, randomRotation);

            //Multiply the tangent to local matrix by the windMatrix, then the random bend matrix, and then the random rotation matrix to 
            //give the transformation matrix for a point not at the base of the blade
            float3x3 tipTransformationMatrix = mul(mul(mul(tangentToLocalSpace, windRotation), randomBend), randomRotation);

            //get random width and height between mins and maxes
            float width = lerp(minWidth, maxWidth, rand(pos.xzy));
            float height = lerp(minHeight, maxHeight, rand(pos.zxy));

            //random extra bend
            float forward = rand(pos.yxz) * bladeBendAmount;

            //We want to use the baseTransformationMatrix when i = 0, otherwise use the tipTransformationMatrix.
            //By setting it here and at the end of the for loop we avoid branching
            float3x3 transformationMatrix = baseTransformationMatrix;

            for (int i = 0; i < BLADE_SEGMENTS; i++) {

                //How far up the blade we are (between 0 and 1)
                float distanceFromGround = i / (float)BLADE_SEGMENTS;

                //Create an offset for the new vertex from the original
                //x = width * 1 / t so blade gets narrower nearer the top
                //y = distance from ground to the power of the blade curve, so blades curve more at the top
                //z = height * distanceFromGround so we work our way up to full height
                float3 offset = float3(width * (1 - distanceFromGround), pow(distanceFromGround, bladeCurve) * forward, height * distanceFromGround);

                //create the grometry data for the two points and add it to the stream
                triStream.Append(CreateTransformedGeometryData(pos, offset, transformationMatrix, float2(0.0f, distanceFromGround)));
                triStream.Append(CreateTransformedGeometryData(pos, float3(-offset.x, offset.y, offset.z), transformationMatrix, float2(1.0f, distanceFromGround)));

                transformationMatrix = tipTransformationMatrix;
            }

            //create geometry data for top point and add it
            triStream.Append(CreateTransformedGeometryData(pos, float3(0.0f, forward, height), tipTransformationMatrix, float2(0.5f, 1.0f)));
        }

        ENDHLSL

        Pass 
        {
            Name "GrassPass"
			Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM

                #pragma target 4.6 // To use tessellation we need at least 4.6

                //Set Shader functions
                #pragma vertex TessVShader
                #pragma require geometry
			    #pragma require tessellation tessHW
                #pragma hull HShader
                #pragma domain DShader
                #pragma geometry GShader
                #pragma fragment FragShader

                #include "Lighting.hlsl"

                float4 FragShader(GeometryData i) : SV_Target
                {
                    float4 color = tex2D(bladeTexture, i.uv);

                    float4 fragColour = color * lerp(bottomColour, topColour, i.uv.y);

                    float4 lighting = GetLambertBlinnPhongForAllLights(fragColour, i.worldPos, i.normal, 0);

                    return GetAmbientLight(fragColour) + lighting;
                }
            ENDHLSL
        }

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
