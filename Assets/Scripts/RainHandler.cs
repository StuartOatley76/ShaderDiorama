using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;


/// <summary>
/// Class to allow cloud states to be set up in editor
/// </summary>
[System.Serializable]
public class CloudState {

    /// <summary>
    /// Power to raise noise to
    /// </summary>
    public float noisePower;

    /// <summary>
    /// Scale of the first noise
    /// </summary>
    public float scale;

    /// <summary>
    /// Speed to move over first noise
    /// </summary>
    public float speed;

    /// <summary>
    /// Cloud colour
    /// </summary>
    [ColorUsage(true, true)]
    public Color colour;

    /// <summary>
    /// Alpha value for clouds
    /// </summary>
    public float alpha;

    /// <summary>
    /// Scale of the second noise
    /// </summary>
    public float distortScale;

    /// <summary>
    /// Speed of the second noise
    /// </summary>
    public float distortSpeed;


    public float offset;
}

/// <summary>
/// Class to handle switching between sunny and rainy
/// </summary>
public class RainHandler : MonoBehaviour
{

    /// <summary>
    /// The particle system for the rain
    /// </summary>
    [SerializeField]
    private ParticleSystem rainParticles;

    /// <summary>
    /// The CloudState for sunny
    /// </summary>
    [SerializeField]
    private CloudState sunnyClouds;

    /// <summary>
    /// The cloudState for rainy
    /// </summary>
    [SerializeField]
    private CloudState rainyClouds;

    /// <summary>
    /// The material used for clouds
    /// </summary>
    [SerializeField]
    private Material cloudMat;

    /// <summary>
    /// The material used for water
    /// </summary>
    [SerializeField]
    private Material waterMat;

    /// <summary>
    /// The material used for raindrops on glass
    /// </summary>
    [SerializeField]
    private Material raindropMat;

    /// <summary>
    /// The material used for puddles on the patio
    /// </summary>
    [SerializeField]
    private Material patioMat;

    /// <summary>
    /// Whether it is raining
    /// </summary>
    private bool raining;

    /// <summary>
    /// The ambient intensity for when it is sunny
    /// </summary>
    [SerializeField]
    private float sunnyAmbient = 1.4f;

    /// <summary>
    /// The ambient intensity for when it is raining
    /// </summary>
    [SerializeField]
    private float rainyAmbient = 0.5f;

    /// <summary>
    /// The directional light's intensity when it is sunny
    /// </summary>
    [SerializeField]
    private float sunnyDirectionalIntensity = 1.06f;

    /// <summary>
    /// The directional light's intensity when it is raining
    /// </summary>
    [SerializeField]
    private float rainyDirectionalIntensity = 0.45f;

    /// <summary>
    /// The alpha level for water when it is sunny
    /// </summary>
    [SerializeField]
    private byte sunnyWaterColourAlpha = 50;

    /// <summary>
    /// The alpha level for water when it is raining
    /// </summary>
    [SerializeField]
    private byte rainyWaterColourAlpha = 150;

    /// <summary>
    /// The maximum offset for rain ripples
    /// </summary>
    [SerializeField]
    private float maxOffset;

    private List<Renderer> cloudRenderers = new List<Renderer>();
    private List<Renderer> waterRenderers = new List<Renderer>();
    private List<Renderer> onOffRenderers = new List<Renderer>();
    private List<Renderer> patioRenderers = new List<Renderer>();

    private List<Light> directionalLights = new List<Light>();
    private List<Light> otherLights = new List<Light>();

    private int timeRainingStarted;

    /// <summary>
    /// Divides all renderers into appropriate lists
    /// </summary>
    private void Start() {

        Renderer[] renderers = FindObjectsOfType<Renderer>();
        foreach(Renderer renderer in renderers) {
            if(renderer.sharedMaterial == cloudMat) {
                cloudRenderers.Add(renderer);
                continue;
            }
            if(renderer.sharedMaterial == waterMat) {
                waterRenderers.Add(renderer);
                onOffRenderers.Add(renderer);
                continue;
            }
            if(renderer.sharedMaterial == raindropMat) {
                onOffRenderers.Add(renderer);
                continue;
            }
            if(renderer.sharedMaterial == patioMat) {
                patioRenderers.Add(renderer);
                onOffRenderers.Add(renderer);
            }
        }

        Light[] lights = FindObjectsOfType<Light>();

        foreach(Light light in lights) {
            if(light.type == LightType.Directional) {
                directionalLights.Add(light);
            } else {
                otherLights.Add(light);
            }
        }

        raining = false;
        SetRainState();
    }

    /// <summary>
    /// Checks for exiting the diorama, a switch between raining and sunny, and
    /// triggers handling raindrop offset
    /// </summary>
    private void Update() {
        if (Input.GetKeyDown(KeyCode.Escape)) {
            SceneManager.LoadScene("Menu");
        }
        if (Input.GetKeyDown(KeyCode.Space)) {
            raining = !raining;
            SetRainState();
        }
        if (raining) {
            HandleRaindropOffset();
        }
    }

    /// <summary>
    /// Switches offsets on rain ripples at the appropriate time to give randomness to
    /// raindrop placement
    /// </summary>
    private void HandleRaindropOffset() {
        int timeRaining = Time.frameCount - timeRainingStarted;
        foreach (Renderer renderer in waterRenderers) {
            float fps = renderer.material.GetFloat("_RaindropsFPS");
            if (timeRaining > 0 && timeRaining % fps == 0) {
                float firstXOffset = Random.Range(0, maxOffset);
                float firstYOffset = Random.Range(0, maxOffset);
                float secondXOffset = Random.Range(0, maxOffset);
                float secondYOffset = Random.Range(0, maxOffset);
                renderer.material.SetVector("_RaindropOffsetOverTime", new Vector2(firstXOffset, firstYOffset));
                renderer.material.SetVector("_RaindropOffsetOverTime2", new Vector2(secondXOffset, secondYOffset));
            }
        }
        foreach (Renderer patioRenderer in patioRenderers) {
            float fps = patioRenderer.material.GetFloat("_RaindropsFPS");
            if (timeRaining > 0 && timeRaining % fps == 0) {
                float xOffset = Random.Range(0, maxOffset);
                float yOffset = Random.Range(0, maxOffset);
                patioRenderer.material.SetVector("_RaindropOffsetOverTime", new Vector2(xOffset, yOffset));
            }
        }
    }

    /// <summary>
    /// Sets everything needed to change state
    /// </summary>
    public void SetRainState() {

        if (raining) {
            timeRainingStarted = Time.frameCount;
        }
        if (rainParticles) {
            switch (raining) {
                case true:
                    rainParticles.Play();
                    break;
                case false:
                    rainParticles.Pause();
                    rainParticles.Clear();
                    break;
            }
        }

        CloudState cloudState = raining ? rainyClouds : sunnyClouds;
        SetClouds(cloudState);
        SetOnOff(onOffRenderers);
        SetWaterAlpha(waterRenderers);
        RenderSettings.ambientIntensity = raining ? rainyAmbient : sunnyAmbient;
        foreach(Light dLight in directionalLights) {
            dLight.intensity = raining ? rainyDirectionalIntensity : sunnyDirectionalIntensity;
        }
        
        foreach(Light oLight in otherLights) {
            oLight.enabled = raining;
        }

        SoundSwitcher.instance.SwitchSounds(raining);
    }

    /// <summary>
    /// Sets the alpha level in water shaders
    /// </summary>
    /// <param name="waterRenderers"></param>
    private void SetWaterAlpha(List<Renderer> waterRenderers) {
        byte alpha = raining ? rainyWaterColourAlpha : sunnyWaterColourAlpha;
        foreach(Renderer renderer in waterRenderers) {
            Color32 color = renderer.material.GetColor("_Colour");
            color.a = alpha;
            renderer.material.SetColor("_Colour", color);
        }
    }

    /// <summary>
    /// Sets values in shaders with the RainOnOff property
    /// </summary>
    /// <param name="renderers"></param>
    private void SetOnOff(params List<Renderer>[] renderers) {
        float onOff = raining ? 1 : 0;
        foreach (List<Renderer> rendererList in renderers) {
            foreach (Renderer renderer in rendererList) {
                renderer.material.SetFloat("_RainOnOff", onOff);
            }
        }
    }

    /// <summary>
    /// Sets values in cloud shaders
    /// </summary>
    /// <param name="cloudState"></param>
    private void SetClouds(CloudState cloudState) {
        foreach(Renderer renderer in cloudRenderers) {
            renderer.material.SetFloat("_Cloud_scale", cloudState.scale);
            renderer.material.SetFloat("_Speed", cloudState.speed);
            renderer.material.SetFloat("_Noise_power", cloudState.noisePower);
            renderer.material.SetColor("_Colour", cloudState.colour);
            renderer.material.SetFloat("_Alpha", cloudState.alpha);
            renderer.material.SetFloat("_DistortScale", cloudState.distortScale);
            renderer.material.SetFloat("_DistortSpeed", cloudState.distortSpeed);
            renderer.material.SetFloat("_offset", cloudState.offset);
        }
    }
}
