using UnityEngine;
using UnityEngine.SceneManagement;

/// <summary>
/// Class to handle menu actions
/// </summary>
public class Menu : MonoBehaviour
{
    /// <summary>
    /// Loads the Diorama
    /// </summary>
    public void EnterDiorama() {
        SceneManager.LoadScene("Diorama");
    }

    /// <summary>
    /// Stops the application running
    /// </summary>
    public void Exit() {
#if UNITY_EDITOR
        UnityEditor.EditorApplication.isPlaying = false;
#else
        Application.Quit();
#endif
    }
}
