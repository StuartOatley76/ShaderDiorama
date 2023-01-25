#ifndef BASIC_VERT
#define BASIC_VERT


    #include "CGBasicStructs.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    
    //Standard vertex shader transforming to world position
    VertexOut VertSetup(VertexIn vIn)
    {
        VertexOut vOut;
        vOut.vertex = float4(TransformObjectToWorld(vIn.vertex.xyz), 1.0f);
        vOut.normal = TransformObjectToWorldNormal(vIn.normal);
        vOut.tangent = vIn.tangent;
        vOut.uv = vIn.uv;

        return vOut;
    }
        

#endif