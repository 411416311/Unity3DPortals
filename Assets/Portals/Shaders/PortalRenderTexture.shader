Shader "Portal/PortalRenderTexture"
{
	Properties
	{
		_LeftEyeTexture("LeftEyeTexture", 2D) = "white" {}
		_RightEyeTexture("RightEyeTexture", 2D) = "white" {}
		_TransparencyMask("TransparencyMask", 2D) = "white" {}
	}

	SubShader
	{
		//LOD 100

		//Pass
		//{
		//	Tags{ "RenderType" = "Opaque" "LightMode" = "Deferred"}
		//	Offset -1.0, -1.0
		//	ZWrite on

		//	CGPROGRAM
		//	#pragma vertex vert
		//	#pragma fragment frag

		//	#include "UnityCG.cginc"

		//	struct appdata
		//	{
		//		float4 vertex : POSITION;
		//	};

		//	struct v2f {
		//		float4 pos : SV_POSITION;
		//		float4 screenPos : TEXCOORD0;
		//	};

		//	v2f vert(appdata v)
		//	{
		//		v2f o;
		//		o.pos = UnityObjectToClipPos(v.vertex);
		//		o.screenPos = ComputeScreenPos(o.pos);
		//		return o;
		//	}

		//	sampler2D _Depth;
		//	sampler2D _GBuf0;
		//	sampler2D _GBuf1;
		//	sampler2D _GBuf2;
		//	sampler2D _GBuf3;

		//	void frag(
		//		v2f i,
		//		out float outDepth : SV_DEPTH,
		//		out half4 outGBuffer0 : SV_Target0, // RT0, ARGB32 format: Diffuse color (RGB), occlusion (A).
		//		out half4 outGBuffer1 : SV_Target1, // RT1, ARGB32 format: Specular color (RGB), roughness (A).
		//		out half4 outGBuffer2 : SV_Target2, // RT2, ARGB2101010 format: World space normal (RGB), unused (A).
		//		out half4 outEmission : SV_Target3	// RT3, emission (rgb), --unused-- (a) |~ Or this one ~| RT3, ARGB2101010 (non-HDR) or ARGBHalf (HDR) format: Emission + lighting + lightmaps + reflection probes buffer.
		//		)
		//	{
		//		// TODO: figure out how to offset this correctly to avoid Z fighting.
		//		outDepth = tex2Dproj(_Depth, UNITY_PROJ_COORD(i.screenPos)) * 1.0001;
		//		outGBuffer0 = tex2Dproj(_GBuf0, UNITY_PROJ_COORD(i.screenPos));
		//		outGBuffer1 = tex2Dproj(_GBuf1, UNITY_PROJ_COORD(i.screenPos));
		//		outGBuffer2 = tex2Dproj(_GBuf2, UNITY_PROJ_COORD(i.screenPos));
		//		outEmission = tex2Dproj(_GBuf3, UNITY_PROJ_COORD(i.screenPos));
		//	}
		//	ENDCG
		//}

		Tags{ "RenderType" = "Transparent" "Queue" = "Transparent" }
		Blend SrcAlpha OneMinusSrcAlpha
		Pass
		{
			Offset -0.1, -10000
			//Offset -1000, -1000

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			#pragma multi_compile __ SAMPLE_PREVIOUS_FRAME DONT_SAMPLE
			#pragma multi_compile __ STEREO_RENDER

			#include "UnityCG.cginc"
			#include "PortalVRHelpers.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float4 uv : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 screenUV : TEXCOORD0;
				float4 objUV : TEXCOORD1;
				UNITY_FOG_COORDS(2)
			};

#ifdef SAMPLE_PREVIOUS_FRAME
			float4x4 PORTAL_MATRIX_VP;
#endif
			sampler2D _LeftEyeTexture;
			sampler2D _RightEyeTexture;
			sampler2D _TransparencyMask;

			v2f vert(appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.objUV = v.uv;
#ifdef SAMPLE_PREVIOUS_FRAME
				// Instead of getting the clip position of our portal from the currently rendering camera,
				// calculate the clip position of the portal from a higher level portal. PORTAL_MATRIX_VP == camera.projectionMatrix.
				float4 recursionClipPos = mul(PORTAL_MATRIX_VP, mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1.0)));

				// TODO: Figure out how to get this value properly (https://docs.unity3d.com/Manual/SL-UnityShaderVariables.html)
				_ProjectionParams.x = 1;
				o.screenUV = ComputeScreenPos(recursionClipPos);
#else
				o.screenUV = ComputeScreenPos(o.pos);
#endif
				UNITY_TRANSFER_FOG(o, o.pos);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				//fixed4 col = PORTAL_VR_CURRENT_EYE == PORTAL_VR_EYE_LEFT ? \
				//	tex2Dproj(_LeftEyeTexture, UNITY_PROJ_COORD(i.uv)) : \
				//	tex2Dproj(_RightEyeTexture, UNITY_PROJ_COORD(i.uv));

				float2 screenUV = i.screenUV.xy / i.screenUV.w;
				fixed4 col;

#ifdef UNITY_SINGLE_PASS_STEREO
				if (PORTAL_VR_CURRENT_EYE == PORTAL_VR_EYE_LEFT)
				{
					screenUV.x *= 2;
					col = tex2D(_LeftEyeTexture, screenUV);
				}
				else
				{
					screenUV.x = (screenUV.x - 0.5) * 2;
					col = tex2D(_RightEyeTexture, screenUV);
				}
#else
				if (PORTAL_VR_CURRENT_EYE == PORTAL_VR_EYE_LEFT)
				{
					col = tex2D(_LeftEyeTexture, screenUV);
				}
				else
				{
					col = tex2D(_RightEyeTexture, screenUV);
				}
#endif

#ifdef DONT_SAMPLE
				col.rgb = fixed3(1, 1, 1);
#endif

				col.a = tex2D(_TransparencyMask, i.objUV).r;
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
	FallBack "VertexLit"
}
