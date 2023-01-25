using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Class to handle passing light information to the shaders that need it
/// Runs in editor and play mode to enable lighting changes to be visible in the editor
/// </summary>
[ExecuteAlways]
public class LightHandler : MonoBehaviour
{
    //Array of all lights in the scene (whether active or not)
    private Light[] lights;

    //Lists to hold active lights of each type
    private List<Light> directionalLights = new List<Light>();
    private List<Light> otherLights = new List<Light>();

    //Maximum numbers for lights (4 directional, 32 point, 32 spot) - change MAXDIRLIGHTS and MAXOTHERLIGHTS in shader if you change these!
    private const int maxDirLights = 4;
    private const int maxOtherLights = 32;

    //Property ID's for directional light information
    private int dirLightCountID = Shader.PropertyToID("_DirectionalLightCount");
    private int dirLightColoursID = Shader.PropertyToID("_DirectionalLightColours");
    private int dirLightDirectionsID = Shader.PropertyToID("_DirectionalLightDirections");

    //Vector arrays for directional light information
    private Vector4[] dirLightDirections = new Vector4[maxDirLights];
    private Vector4[] dirLightColours = new Vector4[maxDirLights];

    //Property ID's for other light information
    private int otherLightCountID = Shader.PropertyToID("_SpotLightCount");
    private int otherLightColoursID = Shader.PropertyToID("_SpotLightColours");
    private int otherLightPositionsID = Shader.PropertyToID("_SpotLightPositions");
    private int otherLightDirectionsID = Shader.PropertyToID("_SpotLightDirections");
    private int otherLightAnglesID = Shader.PropertyToID("_SpotLightAngles");

    private int ambientLightIntensityID = Shader.PropertyToID("_AmbientIntensity");

    //Vector arrays for spotlight information
    private Vector4[] otherLightPositions = new Vector4[maxOtherLights];
    private Vector4[] otherLightColours = new Vector4[maxOtherLights];
    private Vector4[] otherLightDirections = new Vector4[maxOtherLights];
    private Vector4[] otherLightAngles = new Vector4[maxOtherLights];

    /// <summary>
    /// Finds all lights in the scene, whether active or not
    /// </summary>
    private void Start() {
        lights = FindObjectsOfType<Light>(true);
        SetupLights();
    }

    /// <summary>
    /// Clears the lists then adds all active lights to their relevant list
    /// </summary>
    private void SetupLights() {
        directionalLights.Clear();
        otherLights.Clear();
        if (!Application.isPlaying) { //If we're in the editor we need to check whether a new light has been added every update
            lights = FindObjectsOfType<Light>(true);
        }
        foreach(Light light in lights) {
            
            switch (light.type) {
                case LightType.Directional:
                    if (light.isActiveAndEnabled) {
                        directionalLights.Add(light);
                    }
                    break;
                case LightType.Spot:
                case LightType.Point:
                    if (light.isActiveAndEnabled) {
                        otherLights.Add(light);
                    }
                    break;
                default:
                    break;
            }
        }
    }

    /// <summary>
    /// refresh the lists in case lights have been enabled/disabled, 
    /// </summary>
    private void Update() {
        SetupLights();
        UpdateLights();
    }

    /// <summary>
    /// call if a light has beed created or destroyed during play mode/build
    /// </summary>
    public void LightsChanged() {
        lights = FindObjectsOfType<Light>(true);
    }

    /// <summary>
    /// Update lights and pass ambientIntensity to the shaders
    /// </summary>
    private void UpdateLights() {
        UpdateDirectionalLights();
        UpdateOtherLights();
        Shader.SetGlobalFloat(ambientLightIntensityID, RenderSettings.ambientIntensity);
    }

    /// <summary>
    /// Passes non directional lights information to the shaders. For efficiency in the shaders point lights are treated as spot lights
    /// with a 360 degree cone
    /// </summary>
    private void UpdateOtherLights() {
        int spotLightCount = Mathf.Min(otherLights.Count, maxOtherLights);

        for (int i = 0; i < spotLightCount; i++) {
            otherLightColours[i] = otherLights[i].color;
            Vector4 pos = new Vector4(otherLights[i].transform.position.x, otherLights[i].transform.position.y,
                otherLights[i].transform.position.z, 1 / Mathf.Max(otherLights[i].range * otherLights[i].range, 0.00001f));
            otherLightPositions[i] = pos;

            otherLightDirections[i] = -otherLights[i].transform.forward;

            switch (otherLights[i].type) {
                case LightType.Point:
                    float cos = Mathf.Cos(Mathf.Deg2Rad * 0.5f * 360);
                    float cosRcp = 1f / Mathf.Max(cos, 0.00001f);
                    otherLightAngles[i] = new Vector4(cos, cosRcp);
                    break;

                case LightType.Spot:
                    float innerCos = Mathf.Cos(Mathf.Deg2Rad * 0.5f * otherLights[i].innerSpotAngle);
                    float outerCos = Mathf.Cos(Mathf.Deg2Rad * 0.5f * otherLights[i].spotAngle);

                    float innerCosRcp = 1f / Mathf.Max(innerCos - outerCos, 0.00001f);
                    otherLightAngles[i] = new Vector4(outerCos, innerCosRcp);
                    break;
            }

        }
        Shader.SetGlobalInt(otherLightCountID, spotLightCount);
        Shader.SetGlobalVectorArray(otherLightColoursID, otherLightColours);
        Shader.SetGlobalVectorArray(otherLightPositionsID, otherLightPositions);
        Shader.SetGlobalVectorArray(otherLightDirectionsID, otherLightDirections);
        Shader.SetGlobalVectorArray(otherLightAnglesID, otherLightAngles);
    }

    /// <summary>
    /// Passes directional light information to the shaders
    /// </summary>
    private void UpdateDirectionalLights() {
        int directionalLightCount = Mathf.Min(directionalLights.Count, maxDirLights);

        for (int i = 0; i < directionalLightCount; i++) {
            dirLightColours[i] = directionalLights[i].color * directionalLights[i].intensity;
            dirLightDirections[i] = -directionalLights[i].transform.forward;
        }

        Shader.SetGlobalInt(dirLightCountID, directionalLights.Count);
        Shader.SetGlobalVectorArray(dirLightDirectionsID, dirLightDirections);
        Shader.SetGlobalVectorArray(dirLightColoursID, dirLightColours);
    }
}
