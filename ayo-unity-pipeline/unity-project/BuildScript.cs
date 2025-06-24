using UnityEngine;
using UnityEditor;
using System;

public class BuildScript
{
    [MenuItem("Build/Build Android")]
    public static void BuildAndroid()
    {
        string[] scenes = { "Assets/Scenes/MainScene.unity" };
        string buildPath = "Build/Android/AyoDemo.apk";
        
        BuildPipeline.BuildPlayer(scenes, buildPath, BuildTarget.Android, BuildOptions.None);
        
        if (System.IO.File.Exists(buildPath))
        {
            Debug.Log("Build successful: " + buildPath);
        }
        else
        {
            Debug.LogError("Build failed!");
        }
    }

    public static void CommandLineBuild()
    {
        string[] args = Environment.GetCommandLineArgs();
        string buildTarget = "Android";
        
        foreach (string arg in args)
        {
            if (arg.StartsWith("-buildTarget:"))
            {
                buildTarget = arg.Split(':')[1];
            }
        }

        switch (buildTarget.ToLower())
        {
            case "android":
                BuildAndroid();
                break;
            default:
                Debug.LogError("Unknown build target: " + buildTarget);
                break;
        }
    }
}

