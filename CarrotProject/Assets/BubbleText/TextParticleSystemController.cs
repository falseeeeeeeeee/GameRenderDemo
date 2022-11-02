using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;

public class TextParticleSystemController : MonoBehaviour
 {
     public TextMeshPro textMeshPro;
     public ParticleSystem textParticleSystem;
     private ParticleSystemRenderer rendererSystem; 
     // Start is called before the first frame update
     void Start()
     {
         rendererSystem = textParticleSystem.GetComponent<ParticleSystemRenderer>();
         rendererSystem.mesh = textMeshPro.mesh;
     }
 }
