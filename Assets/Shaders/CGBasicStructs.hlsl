#ifndef CG_BASIC_STRUCTS
#define CG_BASIC_STRUCTS

        //Struct to recieve vertex data
        struct VertexIn
        {
            float4 vertex : POSITION;
            float3 normal : NORMAL;
            float4 tangent : TANGENT;
            float2 uv : TEXCOORD0;
        };

        //Struct to output vertex data
        struct VertexOut
        {
            float4 vertex : SV_POSITION;
            float3 normal : NORMAL;
            float4 tangent : TANGENT;
            float2 uv : TEXCOORD0;
        };

        //Struct to hold tessellation data
        struct TessData
        {
            float edge[3] : SV_TESSFACTOR;
            float inside : SV_INSIDETESSFACTOR;
        };

        //Struct to hold information about a new point created during tessellation
        struct TessControlPoint 
        {
            float4 vertex : INTERNALTESSPOS;
            float3 normal : NORMAL;
            float4 tangent : TANGENT;
            float2 uv : TEXCOORD0;
        };
#endif