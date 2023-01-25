#ifndef HLSL_LIGHTING
#define HLSL_LIGHTING


    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

    #define MAXDIRLIGHTS 4
    #define MAXOTHERLIGHTS 32

    CBUFFER_START(UnityPerFrame)
        //Directional light information
        int _DirectionalLightCount;
        float4 _DirectionalLightColours[MAXDIRLIGHTS];
        float4 _DirectionalLightDirections[MAXDIRLIGHTS];

        //Other Light information (Yes, originally this was for spotlights, and I would love to change the names, but if I do, it breaks)
        // 1/range is held in _SpotLightPositions.w. cos of outer cone angle in _SpotLightAngles.x. 
        //reciprocal of inner cone angle is in _SpotLightAngles.y
        int _SpotLightCount;
        float4 _SpotLightColours[MAXOTHERLIGHTS];
        float4 _SpotLightPositions[MAXOTHERLIGHTS];
        float4 _SpotLightDirections[MAXOTHERLIGHTS];
        float4 _SpotLightAngles[MAXOTHERLIGHTS];

        //Ambient light intensity
        float _AmbientIntensity;
    CBUFFER_END


    //Returns the ambient light. unity_AmbientSky gives us the ambient colour, however we need to bring in
    //the intensity
    float4 GetAmbientLight(float4 colour)
    {
        return float4((unity_AmbientSky.xyz * _AmbientIntensity * colour.xyz), colour.w);
    }

    //We can't use the light counts directly, we need to pass them out of a function
    int GetDirectionalLightCount()
    {
        return _DirectionalLightCount;
    }

    int GetSpotLightCount()
    {
        return _SpotLightCount;
    }

    //Calculates Lambert diffuse and Blinn Phong specular
    float4 GetLambertBlinnPhong(float4 fragColour, float3 vertexPos, float3 normal, float3 lightVector,
        float3 lightColour, float gloss, float attenuation)
    {
        float3 lightDirection;
        normal = normalize(normal); // Normal may no longer be normalised because of interpolation

        lightDirection = normalize(lightVector);

        float3 lambert = max(0, dot(normal, lightDirection));
        float3 diffuse = lightColour * fragColour.xyz * lambert;

        float3 viewVector = normalize(GetWorldSpaceViewDir(vertexPos));
        float3 halfVector = normalize(lightVector + viewVector);
        float nDotH = max(0, saturate(dot(normal, halfVector)));

        float smoothness = exp((1 - gloss) * 12) + 2 ;
        float3 specular = pow(nDotH, smoothness) * float3(1, 1, 1);
        specular *= lightColour;

    #if defined(METALLIC)
        specular *= fragColour;
    #endif
        float3 colour = (diffuse + specular) * attenuation;
        return float4(colour.x, colour.y, colour.z, 1);
    }

    //Samples the shadow map to get the attenuation for the main light
    float GetMainShadowAttenuation(float3 position)
    {
        float4 shadowCoord = TransformWorldToShadowCoord(position);
        ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
        half4 shadowParams = GetMainLightShadowParams();
        return SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), shadowCoord, shadowSamplingData, shadowParams, false);
    }

    //Samples the shadow map to get the attenuation for additional lights
    float GetAdditionalShadowAttenuation(int lightIndex, float3 position, float3 lightDirection)
    {
        ShadowSamplingData shadowSamplingData = GetAdditionalLightShadowSamplingData();
        float4 shadowParams = GetAdditionalLightShadowParams(lightIndex);
        int shadowSliceIndex = shadowParams.w;
        float cubemapFaceId = CubeMapFaceID(-lightDirection);
        shadowSliceIndex += cubemapFaceId;

        float4 shadowCoord = mul(_AdditionalLightsWorldToShadow[shadowSliceIndex], float4(position, 1.0));
        return SampleShadowmap(TEXTURE2D_ARGS(_AdditionalLightsShadowmapTexture, sampler_AdditionalLightsShadowmapTexture), shadowCoord, shadowSamplingData, shadowParams, true);
    }

    //Loops through each light getting the shadow attenuation and calculating everything needed for the GetLambertBlinnPhong function
    float4 GetLambertBlinnPhongForAllLights(float4 fragColour, float3 vertexWorldPos, float3 normal,
        float gloss)
    {
        float4 litColour = float4(0, 0, 0, 0);
        float shadowAttenuation = MainLightRealtimeShadow(TransformWorldToShadowCoord(vertexWorldPos));
        int additionalIndex = 0;

        for (int i = 0; i < GetDirectionalLightCount(); i++)
        {
            float3 direction = _DirectionalLightDirections[i].xyz;
            litColour += GetLambertBlinnPhong(fragColour, vertexWorldPos, normal,
                direction, _DirectionalLightColours[i].xyz, gloss, 1 * shadowAttenuation);
        }
        
        for (int k = 0; k < GetSpotLightCount(); k++)
        {
            float3 spotDir = _SpotLightPositions[k].xyz - vertexWorldPos;
            float spotRangeAtten = 1.0 - saturate(length(spotDir) * _SpotLightPositions[k].w);
            spotRangeAtten *= spotRangeAtten;

            float cosAng = dot(normalize(_SpotLightDirections[k].xyz), normalize(spotDir));
            float spotConeAtten = saturate((cosAng - _SpotLightAngles[k].x) * _SpotLightAngles[k].y);
            spotConeAtten *= spotConeAtten;
            float spotAttenuation = spotRangeAtten * spotConeAtten;

            shadowAttenuation = GetAdditionalShadowAttenuation(k, _SpotLightPositions[k].xyz, _SpotLightDirections[k].xyz);
            litColour += GetLambertBlinnPhong(fragColour, vertexWorldPos, normal,
                spotDir, _SpotLightColours[k].xyz, gloss, spotAttenuation * shadowAttenuation);

        }

        return litColour;
    }

    //Function to make this lighting available in shadergraph. Does not work due to unity's include issues - will when they sort them out
    //The include issues are that somewhere they are defining _Time in two seperate files so we end up with a redefinition error
    void LightingForShaderGraph_float(float4 fragColour, float3 vertexWorldPos, float3 normal,
        float smoothness, out float4 colour)
    {
        colour = GetLambertBlinnPhongForAllLights(fragColour, vertexWorldPos, normal, smoothness);
    }

#endif