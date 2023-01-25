Shader "Stuart/Windows"
{
    Properties
    {

        _IsRaining("Is raining (0 = false, 1 = true)", float) = 0
        _Drops("Rain Drops Texture", 2D) = "white" {}
        _DropTilingX("Drop tiling X", float) = 0.75
        _DropTilingY("Drop tiling Y", float) = 0.75
        _RainingAlpha("Raining alpha", float) = 0.57
        _RainDistortion("Rain distortion strength", float) = 0.13
        _Speed("Speed", float) = 0.1
        
        _Drips("Rain drips texture", 2D) = "white" {}
        _DripTilingX("Drip tiling X", float) = 0.75
        _DripTilingY("Drip tiling Y", float) = 0.75
        _DripMaxSpeed("Drip max speed", float) = 0.25
        _DripMinSpeed("Drip min speed", float) = 0.1
        _DripsShapeMask("Rain Drips Shape Mask", 2D) = "white" {}
        _DripsSize("Rain Drips Size", float) = 1.62
        _Cube("Reflection Map", CUBE) = "" {}
    }
        SubShader
        {
            Tags { "Queue" = "Transparent" "RenderType" = "Transparent"}
            LOD 100

            Pass
            {
                HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #pragma target 4.6

                #include "Lighting.hlsl"
                #include "Shadows.hlsl"
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"
                 
                CBUFFER_START(UnityPerMaterial)
                    float _IsRaining;
                    sampler2D _Drops;
                    float4 _Drops_ST;
                    float _DropTilingX;
                    float _DropTilingY;
                    float _RainingAlpha;
                    float _RainDistortion;
                    float _Speed;
                    sampler2D _Drips;
                    float4 _Drips_ST;
                    float _DripTilingX;
                    float _DripTilingY;
                    float _DripMaxSpeed;
                    float _DripMinSpeed;
                    sampler2D _DripsShapeMask;
                    float4 _DripsMask_ST;
                    float _DripsSize;
                    sampler2D _CameraOpaqueTexture;
                    samplerCUBE _Cube;
                CBUFFER_END

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertexCS : SV_POSITION;
                float4 vertexWS : TEXCOORD1;
                float3 normal : NORMAL;
                float4 screenPos : TEXCOORD2;
                float3 viewDir : TEXCOORD3;
            };

            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertexCS = TransformObjectToHClip(v.vertex.xyz);
                o.vertexWS = float4(TransformObjectToWorld(v.vertex.xyz), 1);
                o.uv = TRANSFORM_TEX(v.uv, _Drops);
                o.normal = v.normal;
                o.screenPos = ComputeScreenPos(o.vertexCS);
                o.viewDir = normalize(GetWorldSpaceNormalizeViewDir(o.vertexWS));
                return o;
            }


            float normalMultiplier = 6;
            float normalSubtraction = 3;

            //Creates the 
            float2 GetDropOffset(float2 pos) {
                
                //Create normals - we want strong so instead of *2 -1 we *6 -3
                float2 uv = pos * float2(_DropTilingX, _DropTilingY);
                float4 dropSample = tex2D(_Drops, uv);
                float3 strongNormal = dropSample.xyw * normalMultiplier - normalSubtraction;

                //create temporal mask
                float tempMask = frac(_Time.y * _Speed) - dropSample.z;

                //This will be 1 if animated or 0 if static
                float toAnimate = strongNormal.z;

                //Calculate values for animated by saturating and multiplying by the tempMask, and non animated by saturating the
                //negative. At least one of these will be zero. We then add them together to give our offset amount.
                float animated = saturate(toAnimate) * tempMask;
                float nonAnimated = saturate(-animated);
                float toOffset = animated + nonAnimated;

                //Multiply by the sampled XY and our distortion strength to give our screen colour offset
                float2 dropUVOffset = strongNormal.xy * _RainDistortion * toOffset;

                return dropUVOffset;
            }

            float2 shapeMaskScale = float2(2, -0.5);

            float2 GetDripOffset(float2 pos) {

                //Create normals we want strong so instead of *2 -1 we *6 -3
                float2 uv = pos * float2(_DripTilingX, _DripTilingY);
                float4 dripSample = tex2D(_Drips, uv * _DripsSize);
                float2 strongNormal = dripSample.xy * normalMultiplier - normalSubtraction;

                //Speed of drip (negated as we want drips to travel down)
                float speed = lerp(-_DripMaxSpeed, -_DripMinSpeed, dripSample.w);

                //add time and w channel then multiply by speed
                float dripTime = _Time.y + dripSample.w;
                float movement = speed * dripTime;

                //Scale UVs for mask
                float2 scaledUV = uv * shapeMaskScale;

                //Add speed
                float2 shapeMaskUV = scaledUV + speed;

                float4 maskSample = tex2D(_DripsShapeMask, shapeMaskUV);

                //Create temporal mask
                float tempMask = round(dripSample.y);

                //Apply temporal mask
                float shape = maskSample.x * tempMask;

                float2 dripOffsetUV = shape * strongNormal;

                return dripOffsetUV;
            }

            float3 frag(v2f i) : SV_Target
            {
                float2 pos = i.vertexWS.xy;
                 
                float2 offset = float2(0, 0);

                offset += GetDropOffset(pos);

                offset += GetDripOffset(pos);

                //offset *= _IsRaining;

                pos += offset;

                float4 posWS = float4(pos.x , pos.y, i.vertexWS.z, i.vertexWS.w);

                float4 posCS = TransformWorldToHClip(posWS);


                float alpha = _RainingAlpha;// *_IsRaining;

                float4 screenPos = ComputeScreenPos(posCS);

                float4 col = tex2Dproj(_CameraOpaqueTexture, screenPos);

                col.a = alpha;

                return col;
            }
            ENDHLSL
        }
    }
}
