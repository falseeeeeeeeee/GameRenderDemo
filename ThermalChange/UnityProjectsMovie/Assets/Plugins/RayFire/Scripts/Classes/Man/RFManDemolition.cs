using System;

namespace RayFire
{
    [Serializable]
    public class RFManDemolition
    {
        // Post dml fragments 
        public enum FragmentParentType
        {
            Manager = 0,
            Parent  = 1
        }

        public FragmentParentType parent;
        public int                maximumAmount = 1000;
        public int                badMeshTry    = 3;
        public float              sizeThreshold = 0.05f;
        public int                currentAmount;
        
        // TODO Inherit velocity by impact normal
    }
}