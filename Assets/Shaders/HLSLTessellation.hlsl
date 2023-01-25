#ifndef HLSL_TESSELLATION
#define HLSL_TESSELLATION


        #include "CGBasicStructs.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Lighting.hlsl"
        #include "BasicVert.hlsl"
        
        //The Vertex Shader
        TessControlPoint TessVShader(VertexIn v)
        {
            TessControlPoint p;
            p.vertex = v.vertex;
            p.normal = v.normal;
            p.tangent = v.tangent;
            p.uv = v.uv;
            return p;
        }

        //The hull shader
        [domain("tri")] //Lets the hull shader know it's working with triangles
        [outputcontrolpoints(3)] //Specifies we're outputting 3 control points per patch
        [outputtopology("triangle_cw")] //Specifies the triangles are defined clockwise
        [partitioning("fractional_odd")] //Allows fractional subdivisions
        [patchconstantfunc("PatchConstant")] //Defines the function to use to tell how many parts the patch should be cut into
        TessControlPoint HShader(InputPatch<TessControlPoint, 3> patch, uint id:SV_OUTPUTCONTROLPOINTID)
        {
            return patch[id];
        }

        float tessellationUniform;
        float tessellationEdgeLength;


        //Allows for reduction of verts created based on distance from the camera if TESSELLATION_EDGE is defined
        float TessEdgeFactor(float3 p1, float3 p2)
        {
            #if defined(TESSELLATION_EDGE)
                float edgeLength = distance(p1, p2);
                float3 edgeCentre = (p1 - p2) * 0.5f;
                float viewDistance = distance(edgeCentre, _WorldSpaceCameraPos);

                return edgeLength * _ScreenParams.y / (tessellationEdgeLength * viewDistance);
            #else
                return tessellationUniform;
            #endif
        }

        //Creates the new triangle as a TessData
        TessData PatchConstant(InputPatch<TessControlPoint, 3> patch)
        {
            //Convert vertices to world positions
            float3 worldP0 = mul(unity_ObjectToWorld, patch[0].vertex).xyz;
            float3 worldP1 = mul(unity_ObjectToWorld, patch[1].vertex).xyz;
            float3 worldP2 = mul(unity_ObjectToWorld, patch[2].vertex).xyz;

            TessData data;

            //Calculate edges
            data.edge[0] = tessellationUniform;
            data.edge[1] = tessellationUniform;
            data.edge[2] = tessellationUniform;

            //Calculate inside. Note - this looks like it is repeating the above stages... because it is
            //this is to prevent a bug in openGL where if we were just to use the data edges we just calculated
            //it would try and do this parrallely and calculate the inside before the edges were all set
            data.inside = tessellationUniform * (1/3.0) ;
            return data;
        }

        // Creates the vertexOut data. Called by the domain shader to prepare for the fragment shader
        VertexOut VertSet(VertexIn vIn)
        {
            VertexOut vOut;
            vOut.vertex = vIn.vertex;
            vOut.normal = vIn.normal;
            vOut.tangent = vIn.tangent;
            vOut.uv = vIn.uv;

            return vOut;
        }

        [domain("tri")] //Lets the domain shader know it's working with triangles
        VertexOut DShader(TessData data, OutputPatch<TessControlPoint, 3> patch, float3 barycentricCoordinates : SV_DOMAINLOCATION)
        {
            VertexIn vert;

            //define macro to interpolate the patch data with the barycentric coordinates
            #define DOMAIN_INTERPOLATE(fieldName) vert.fieldName = \
                patch[0].fieldName * barycentricCoordinates.x + \
                patch[1].fieldName * barycentricCoordinates.y + \
                patch[2].fieldName * barycentricCoordinates.z;
            
            DOMAIN_INTERPOLATE(vertex);
            DOMAIN_INTERPOLATE(normal);
            DOMAIN_INTERPOLATE(tangent);
            DOMAIN_INTERPOLATE(uv);

            return VertSet(vert);
        }

#endif