using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class postprocess : MonoBehaviour
{
    public Material mat;
    public int pass=0;
    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (mat != null)
        {
            Graphics.Blit(src,dest,mat,pass);
        }
    }
}
