using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class InteractiveRTCamera : MonoBehaviour
{
    public Transform FollowTarget;
    
    private Camera _camera;
    private RenderTexture _renderTexture;

    private void Start()
    {
        _camera = GetComponent<Camera>();
        _camera.backgroundColor = new Color(0.5f, 0.5f, 0, 1).gamma;

        if (_renderTexture == null)
        {
            _renderTexture = RenderTexture.GetTemporary(1024, 1024, 16, RenderTextureFormat.ARGB32);
            _renderTexture.useMipMap = false;
            _renderTexture.filterMode = FilterMode.Point;
        }

        _camera.aspect = 1;
        _camera.targetTexture = _renderTexture;
        
        Shader.SetGlobalTexture("_InteractiveTex", _renderTexture);
        
        Vector3 interactiveCamData = new Vector3(transform.position.x, _camera.orthographicSize, transform.position.z);
        Shader.SetGlobalVector("_InteractiveCamData", interactiveCamData);
    }

    private void Update()
    {
        if (FollowTarget != null)
        {
            transform.position = FollowTarget.position;
        }
    }

    private void OnDestroy()
    {
        if (_renderTexture != null)
        {
            RenderTexture.ReleaseTemporary(_renderTexture);
            _renderTexture = null;
        }
    }
}
