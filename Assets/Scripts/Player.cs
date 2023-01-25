using UnityEngine;

/// <summary>
/// Class to handle player movement
/// </summary>
[RequireComponent(typeof(CharacterController))]
public class Player : MonoBehaviour
{

    /// <summary>
    /// The character controller attached to the gameobject
    /// </summary>
    private CharacterController controller;

    /// <summary>
    /// Movement speed
    /// </summary>
    [SerializeField]
    private float speed;

    /// <summary>
    /// Mouse sensitivity
    /// </summary>
    [SerializeField]
    private Vector2 sensitivity;

    /// <summary>
    /// limits rotational movement speed increase per frame to prevent jerkiness
    /// </summary>
    [SerializeField]
    private Vector2 rotationAcceleration;

    /// <summary>
    /// How long to ignore zero inputs for. 
    /// prevents issues with the game updating faster than the input devices
    /// </summary>
    [SerializeField]
    private float inputLagIgnoreTime;

    /// <summary>
    /// Limits up/down rotation
    /// </summary>
    [SerializeField]
    private float verticalClampAngle;

    /// <summary>
    /// The last valid input. used to ignore 0,0,0 for small amounts of time
    /// </summary>
    private Vector2 lastValidInput;

    /// <summary>
    /// time since the last valid input
    /// </summary>
    private float timeSinceLastValid;

    /// <summary>
    /// velocity of rotation
    /// </summary>
    private Vector2 rotationVelocity;

    /// <summary>
    /// Rotation
    /// </summary>
    private Vector2 rotation;

    /// <summary>
    /// Gets the character controller
    /// </summary>
    void Start() {

        controller = GetComponent<CharacterController>();
    }

    /// <summary>
    /// Handles directional input
    /// </summary>
    void Update() {

        Vector3 move = new Vector3(Input.GetAxis("Horizontal"), 0, Input.GetAxis("Vertical"));
        move = transform.TransformDirection(move);
        move.y = 0;
        controller.Move(move * speed * Time.deltaTime);
        Vector2 inputRotation = GetRotationInput();

        rotationVelocity = new Vector2(
                Mathf.MoveTowards(rotationVelocity.x, inputRotation.x, rotationAcceleration.x * Time.deltaTime),
                Mathf.MoveTowards(rotationVelocity.y, inputRotation.y, rotationAcceleration.y * Time.deltaTime)
            );
        rotation += rotationVelocity * Time.deltaTime;

        rotation.y = Mathf.Clamp(rotation.y, -verticalClampAngle, verticalClampAngle);
        transform.localEulerAngles = new Vector3(rotation.y, rotation.x, 0);

    }

    /// <summary>
    /// Handles rotational input, including ignoring 0,0,0 for small amount of time
    /// </summary>
    /// <returns></returns>
    private Vector2 GetRotationInput() {
        timeSinceLastValid += Time.deltaTime;

        Vector2 inputRotation = new Vector2(Input.GetAxisRaw("Mouse X"), -Input.GetAxisRaw("Mouse Y")) * sensitivity;

        if (!(Mathf.Approximately(0, inputRotation.x) && Mathf.Approximately(0, inputRotation.y)) || timeSinceLastValid > inputLagIgnoreTime) {
            lastValidInput = inputRotation;
            timeSinceLastValid = 0;
        }

        return lastValidInput;
    }
}
