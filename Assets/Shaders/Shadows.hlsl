#ifndef SHADOWS_HLSL
#define SHADOWS_HLSL
	
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
	
	//For the shadowmap pass we only need position

	struct VertexData
	{
		float4 positionOS : POSITION;
	};

	struct fragData
	{
		float4 positionCS : SV_POSITION;
	};


	//Vertex shader - Creation of the VertexPositionInputs adds the vertex to Unity's shadowmap
	fragData shadowVert(VertexData vIn)
	{
		fragData output;
		VertexPositionInputs inputs = GetVertexPositionInputs(vIn.positionOS.xyz);
		output.positionCS = inputs.positionCS;
		return output;
	}

	//No need to do anything in the fragment shader
	float4 shadowFrag(fragData fIn) : SV_TARGET
	{
		return 0;
	}
#endif