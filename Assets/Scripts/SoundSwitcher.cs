using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Singleton class to handle switching between background sounds
/// </summary>
[RequireComponent(typeof(AudioSource))]
public class SoundSwitcher : MonoBehaviour
{
    /// <summary>
    /// The instance of this singleton
    /// </summary>
    static public SoundSwitcher instance;

    /// <summary>
    /// Audio clip to be played when diorama is in sunny state
    /// </summary>
    [SerializeField]
    private AudioClip sunnyClip;

    /// <summary>
    /// Audio clip to be played when diorama is in rainy state
    /// </summary>
    [SerializeField]
    private AudioClip rainyClip;

    /// <summary>
    /// The audio source attached to this gameobject
    /// </summary>
    private AudioSource audioSource;

    /// <summary>
    /// Sets up sinleton instance and finds audio source
    /// </summary>
    private void Awake() {
        if(instance != null) {
            Destroy(this);
            return;
        }
        instance = this;
        audioSource = GetComponent<AudioSource>();
    }

    /// <summary>
    /// Switches to the appropriate sound clip
    /// </summary>
    /// <param name="isRaining"></param>
    public void SwitchSounds(bool isRaining) {
        audioSource.Stop();
        audioSource.clip = isRaining ? rainyClip : sunnyClip;
        audioSource.Play();
    }

}
