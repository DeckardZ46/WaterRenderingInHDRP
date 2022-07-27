using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class CameraRenderer
{
    ScriptableRenderContext context;
    Camera camera;
    public void Render(ScriptableRenderContext context, Camera camera)
    {
        this.context = context;
        this.camera = camera;

        DrawVisibleGeometry();
        Submit();
    }

    void Submit (){
        context.Submit();
    }
    void DrawVisibleGeometry()
    {
        context.DrawSkybox(camera);
    }

}

