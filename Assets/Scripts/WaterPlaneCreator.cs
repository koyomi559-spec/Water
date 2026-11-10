using UnityEngine;

[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class WaterPlaneCreator : MonoBehaviour
{
    private Mesh _waterMesh;

    private void Start()
    {
        // segment表示细分成100个边
        const int segments = 200;
        // size表示平面具体大小
        const float size = 10f;
        //row表示每个边长的顶点数
        int row = segments + 1;
        
        
        Vector3[] vertices = new Vector3[row * row];
        Vector2[] uv = new Vector2[vertices.Length];
        int[] triangles = new int[segments * segments * 6];

        // 从左到右、从前到后，逐行排列顶点。
        // 物理空间信息存入vertices
        // uv信息存入uv, uv信息算法即将3d空间的模型映射到0-1中（uv）空间
        for (int z = 0; z < row; z++)
        {
            for (int x = 0; x < row; x++)
            {
                int index = z * row + x;
                float u = (float)x / segments;
                float v = (float)z / segments;

                vertices[index] = new Vector3(
                    (u - 0.5f) * size,
                    0f,
                    (v - 0.5f) * size
                );

                uv[index] = new Vector2(u, v);
            }
        }

        // 每个小格连接成两个朝上的三角形。
        int t = 0;
        for (int z = 0; z < segments; z++)
        {
            for (int x = 0; x < segments; x++)
            {
                int a = z * row + x;
                int b = a + 1;
                int c = a + row;
                int d = c + 1;

                triangles[t++] = a;
                triangles[t++] = c;
                triangles[t++] = b;

                triangles[t++] = b;
                triangles[t++] = c;
                triangles[t++] = d;
            }
        }

        _waterMesh = new Mesh { name = "Water Grid" };
        _waterMesh.vertices = vertices;
        _waterMesh.uv = uv;
        _waterMesh.triangles = triangles;
        _waterMesh.RecalculateNormals();
        _waterMesh.RecalculateBounds();

        GetComponent<MeshFilter>().sharedMesh = _waterMesh;

        Debug.Log($"水面：{vertices.Length} 个顶点，" +
                  $"{triangles.Length / 3} 个三角形");
    }

    private void OnDestroy()
    {
        if (_waterMesh != null)
            Destroy(_waterMesh);
    }
}