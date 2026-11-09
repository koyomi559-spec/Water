using System.IO;
using System.Linq;
using System.Text;
using System.Xml.Linq;
using UnityEditor;
using UnityEngine;

public class UnitySourceGeneratorProjectFix : AssetPostprocessor
{
    private static string OnGeneratedCSProject(string path, string content)
    {
        var project = XDocument.Parse(content);
        var ns = project.Root.Name.Namespace;
        var analyzers = project.Descendants(ns + "Analyzer");
        if (!analyzers.Any(item => Path.GetFileName((string)item.Attribute("Include")) == "Unity.SourceGenerators.dll"))
            return content;

        var additionalFiles = project.Descendants(ns + "AdditionalFiles");
        if (additionalFiles.Any(item => ((string)item.Attribute("Include") ?? "").EndsWith(".UnityAdditionalFile.txt")))
            return content;

        // Unity's generator expects one text file containing the project root, without a trailing newline.
        var projectRoot = Directory.GetParent(Application.dataPath).FullName;
        const string relativePath = "Library/MonoScriptInfoGenerator.UnityAdditionalFile.txt";
        var additionalFilePath = Path.Combine(projectRoot, relativePath);
        Directory.CreateDirectory(Path.GetDirectoryName(additionalFilePath));
        File.WriteAllText(additionalFilePath, projectRoot, new UTF8Encoding(false));

        var itemGroup = "  <ItemGroup>\n    <AdditionalFiles Include=\""
                        + relativePath
                        + "\" />\n  </ItemGroup>\n";
        return content.Insert(content.LastIndexOf("</Project>", System.StringComparison.Ordinal), itemGroup);
    }
}