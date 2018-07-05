//
//  SceneAnimatedMesh.m
//
//

#import "SceneAnimatedMesh.h"


/////////////////////////////////////////////////////////////////
// Constants that control the size of the mesh
#define NUM_MESH_ROWS (20)     // Must be at least 2
#define NUM_MESH_COLUMNS (40)  // Must be at least 2
#define NUM_MESH_TRIANGLES ((NUM_MESH_ROWS - 1) * \
   (NUM_MESH_COLUMNS - 1) * 2)

/////////////////////////////////////////////////////////////////
// The number of indices is the number of triangles in mesh 
// plus 2 plus number degenerate triangles (NUM_MESH_COLUMNS - 2) 
#define NUM_MESH_INDICES (NUM_MESH_TRIANGLES + 2 + \
   (NUM_MESH_COLUMNS - 2))


@interface SceneAnimatedMesh ()
{
   SceneMeshVertex  mesh[NUM_MESH_COLUMNS][NUM_MESH_ROWS];
}

@end


/////////////////////////////////////////////////////////////////
// Forward declarations
static void SceneMeshInitIndices(
   GLushort meshIndices[NUM_MESH_INDICES]);
static void SceneMeshUpdateNormals(
   SceneMeshVertex mesh[NUM_MESH_COLUMNS][NUM_MESH_ROWS]);
static void SceneMeshUpdateMeshWithDefaultPositions(
   SceneMeshVertex mesh[NUM_MESH_COLUMNS][NUM_MESH_ROWS]);


@implementation SceneAnimatedMesh

/////////////////////////////////////////////////////////////////
// Designated initializer: creates vertex attribute array and
// initializes indices for sharing triangle vertices in mesh.
- (id)init
{
   GLushort         meshIndices[NUM_MESH_INDICES];
   
   // Setup indices
   SceneMeshInitIndices(meshIndices);

   // Setup default positions and texture coordiantes
   SceneMeshUpdateMeshWithDefaultPositions(mesh);
   
   // Create the NSData objects needed by super class.
   NSData *someMeshData = [NSData dataWithBytesNoCopy:mesh 
      length:sizeof(mesh) freeWhenDone:NO];
   NSData *someIndexData = [NSData dataWithBytes:meshIndices 
      length:sizeof(meshIndices)];
      
   return [self initWithVertexAttributeData:someMeshData
      indexData:someIndexData];
}


/////////////////////////////////////////////////////////////////
// Draw the entire mesh after it has been prepared for drawing
- (void)drawEntireMesh;
{
   //在准备的顶点缓冲区中使用顶点绘制三角形，并从绑定元素数组缓冲区中绘制索引。
    glDrawElements(GL_TRIANGLE_STRIP,
                   NUM_MESH_INDICES,
                   GL_UNSIGNED_SHORT, 
                   (GLushort *)NULL);
}


/////////////////////////////////////////////////////////////////
// Revert to defualt vertex attribtes 
- (void)updateMeshWithDefaultPositions;
{
   SceneMeshUpdateMeshWithDefaultPositions(mesh);
   
   [self makeDynamicAndUpdateWithVertices:&mesh[0][0]
      numberOfVertices:sizeof(mesh) / sizeof(SceneMeshVertex)];
}


//该方法修改顶点位置并重新计算法线。在这个类的-draw方法中，顶点属性数组被修改后的顶点数据重新初始化。
- (void)updateMeshWithElapsedTime:(NSTimeInterval)anInterval;
{  
   int    currentRow;
   int    currentColumn;
   
   // For each position along +X axis of mesh
   for(currentColumn = 0; currentColumn < NUM_MESH_COLUMNS; currentColumn++)
   {
      const GLfloat phaseOffset = 2.0f * anInterval;
      const GLfloat phase = 4.0 * currentColumn / (float)NUM_MESH_COLUMNS;
       
       //改变y值,利用正弦函数来产生一个波动的效果
      const GLfloat yOffset = 2.0 * sinf(M_PI * (phase + phaseOffset));
   
      // For each position along -Z axis of mesh
      for(currentRow = 0; currentRow < NUM_MESH_ROWS; currentRow++)
      {
         mesh[currentColumn][currentRow].position.y = yOffset;
      }
   }  
   
    //重新计算法向量
   SceneMeshUpdateNormals(mesh);
   
    //该方法向GPU发送从某些暗点读取的顶点属性的计数集。此方法还将生成的顶点属性数组标记为易于频繁更新的动态数组。
   [self makeDynamicAndUpdateWithVertices:&mesh[0][0]
                         numberOfVertices:sizeof(mesh) / sizeof(SceneMeshVertex)];
}

@end


/////////////////////////////////////////////////////////////////
// Revert mesh to defualt vertex attribtes 
void SceneMeshUpdateMeshWithDefaultPositions(
   SceneMeshVertex mesh[NUM_MESH_COLUMNS][NUM_MESH_ROWS])
{
   int    currentRow;
   int    currentColumn;
   
   // For each position along +X axis of mesh
   for(currentColumn = 0; currentColumn < NUM_MESH_COLUMNS; 
      currentColumn++)
   {
         
      // For each position along -Z axis of mesh
      for(currentRow = 0; currentRow < NUM_MESH_ROWS; currentRow++)
      {
         mesh[currentColumn][currentRow].position = 
            GLKVector3Make(
               currentColumn, 
               0.0f, 
               -currentRow);
               
         GLKVector2 textureCoords = GLKVector2Make(
            (float)currentRow / (NUM_MESH_ROWS - 1),
            (float)currentColumn / (NUM_MESH_COLUMNS - 1));
            
         mesh[currentColumn][currentRow].texCoords0 = 
            textureCoords;
      }
   }  

   SceneMeshUpdateNormals(mesh);
}


/////////////////////////////////////////////////////////////////
// Initialize the indices needed to draw the animatable mesh as
// one large triangle strip
void SceneMeshInitIndices(GLushort meshIndices[NUM_MESH_INDICES])
{
   int    currentRow = 0;
   int    currentColumn = 0;
   int    currentMeshIndex = 0;
   
   // Start at 1 because algorithm steps back one index at start
   currentMeshIndex = 1;  
   
   // For each position along +X axis of mesh
   for(currentColumn = 0; currentColumn < (NUM_MESH_COLUMNS - 1);
      currentColumn++)
   {
      if(0 == (currentColumn % 2))
      { // This is an even column
         currentMeshIndex--; // back: overwrite duplicate vertex 
         
         // For each position along -Z axis of mesh
         for(currentRow = 0; currentRow < NUM_MESH_ROWS;
            currentRow++)
         {
            meshIndices[currentMeshIndex++] =  
               currentColumn * NUM_MESH_ROWS + 
               currentRow;
            meshIndices[currentMeshIndex++] = 
               (currentColumn + 1) * NUM_MESH_ROWS + 
               currentRow;
         }
      }
      else
      { // This is an odd column
         currentMeshIndex--; // back: overwrite duplicate vertex
         
         // For each position along -Z axis of mesh
         for(currentRow = NUM_MESH_ROWS - 1; currentRow >= 0;
            currentRow--)
         {
            meshIndices[currentMeshIndex++] =  
               currentColumn * NUM_MESH_ROWS + 
               currentRow;
            meshIndices[currentMeshIndex++] = 
               (currentColumn + 1) * NUM_MESH_ROWS + 
               currentRow;
         }
      }
   }

   NSCAssert(currentMeshIndex == NUM_MESH_INDICES, 
      @"Incorrect number of indices intialized.");
}


//通过对每个顶点附近四个平面的法向量求平均值，计算平滑法向量。每当顶点位置发生变化时，必须重新计算法向量。
void SceneMeshUpdateNormals(SceneMeshVertex mesh[NUM_MESH_COLUMNS][NUM_MESH_ROWS])
{
   int    currentRow;
   int    currentColumn;
   
   // Calculate normals for vertices internal to the mesh
   for(currentRow = 1; currentRow < (NUM_MESH_ROWS - 1); 
      currentRow++)
   {
      for(currentColumn = 1; currentColumn < (NUM_MESH_COLUMNS - 1); 
         currentColumn++)
      {
         GLKVector3 position = 
            mesh[currentColumn][currentRow].position;
         
         GLKVector3 vectorA = GLKVector3Subtract(
            mesh[currentColumn][currentRow+1].position,
            position);
         GLKVector3 vectorB = GLKVector3Subtract(
            mesh[currentColumn+1][currentRow].position,
            position);
         GLKVector3 vectorC = GLKVector3Subtract(
            mesh[currentColumn][currentRow-1].position,
            position);
         GLKVector3 vectorD = GLKVector3Subtract(
            mesh[currentColumn-1][currentRow].position,
            position);
            
         // Calculate normal vectors for four planes
         GLKVector3   normalBA = 
            GLKVector3CrossProduct(vectorB, vectorA);
         GLKVector3   normalCB = 
            GLKVector3CrossProduct(vectorC, vectorB);
         GLKVector3   normalDC = 
            GLKVector3CrossProduct(vectorD, vectorC);
         GLKVector3   normalAD = 
            GLKVector3CrossProduct(vectorA, vectorD);

         // Store the average the face normal vectors of the 
         // four triangles that share the current vertex
         mesh[currentColumn][currentRow].normal = 
            GLKVector3MultiplyScalar(
               GLKVector3Add(
                  GLKVector3Add(
                     GLKVector3Add(
                        normalBA, 
                        normalCB), 
                     normalDC), 
                  normalAD), 
               0.25);
      }
   } 
   
   // Calculate normals along X max and X min edges
   for(currentRow = 0; currentRow < NUM_MESH_ROWS; 
      currentRow++)
   {
      mesh[0][currentRow].normal = 
         mesh[1][currentRow].normal;
      mesh[NUM_MESH_COLUMNS-1][currentRow].normal = 
         mesh[NUM_MESH_COLUMNS-2][currentRow].normal;
   }
    
   // Calculate normals along Z max and Z min edges
   for(currentColumn = 0; currentColumn < NUM_MESH_COLUMNS; 
      currentColumn++)
   {
      mesh[currentColumn][0].normal = 
         mesh[currentColumn][1].normal;
      mesh[currentColumn][NUM_MESH_ROWS-1].normal = 
         mesh[currentColumn][NUM_MESH_ROWS-2].normal;
   }
}
