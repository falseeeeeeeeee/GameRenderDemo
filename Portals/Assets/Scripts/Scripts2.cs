using UnityEngine;

public class Scripts2 : MonoBehaviour
{
    public static Scripts1 scripts;
    void Start()
    {
        scripts = FindObjectOfType<Scripts1>();
        
        if (scripts != null)
        {
            Debug.LogError("Script not found!");
        }
    }
}