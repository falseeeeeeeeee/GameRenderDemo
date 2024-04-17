using UnityEngine;

public class Scripts1 : MonoBehaviour
{
    public static Scripts1 instance;

    public void Awake()
    {
        instance = this;
    }
    
    public void MainMethod()
    {
        Debug.Log("Call Method");
    }
}