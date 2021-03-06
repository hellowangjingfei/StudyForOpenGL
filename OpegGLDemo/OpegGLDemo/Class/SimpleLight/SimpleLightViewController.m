//
//  SimpleLightViewController.m
//  OpegGLDemo
//
//  Created by 范杨 on 2018/5/11.
//  Copyright © 2018年 RPGLiker. All rights reserved.
//

#import "SimpleLightViewController.h"
#import <GLKit/GLKit.h>
#import "AGLKVertexAttribArrayBuffer.h"

typedef struct {
    GLKVector3  position;
    GLKVector3  normal;
}SceneVertex;

typedef struct {
    SceneVertex vertices[3];
}SceneTriangle;

//九个三角顶点
static const SceneVertex vertexA = {{-0.5,  0.5, -0.5}, {0.0, 0.0, 1.0}};
static const SceneVertex vertexB = {{-0.5,  0.0, -0.5}, {0.0, 0.0, 1.0}};
static const SceneVertex vertexC = {{-0.5, -0.5, -0.5}, {0.0, 0.0, 1.0}};
static const SceneVertex vertexD = {{ 0.0,  0.5, -0.5}, {0.0, 0.0, 1.0}};
static const SceneVertex vertexE = {{ 0.0,  0.0, -0.5}, {0.0, 0.0, 1.0}};
static const SceneVertex vertexF = {{ 0.0, -0.5, -0.5}, {0.0, 0.0, 1.0}};
static const SceneVertex vertexG = {{ 0.5,  0.5, -0.5}, {0.0, 0.0, 1.0}};
static const SceneVertex vertexH = {{ 0.5,  0.0, -0.5}, {0.0, 0.0, 1.0}};
static const SceneVertex vertexI = {{ 0.5, -0.5, -0.5}, {0.0, 0.0, 1.0}};

//渲染由八个三角组成,四个侧面三角,四个地面三角
#define NUM_FACES (8)

//需要四十八个顶点画出所有三角形的法向量 8 * 3 * 2
#define NUM_NORMAL_LINE_VERTS (48)

//需要五十个定点来画出所有三角形顶点的法向量,两个点画出光的方向 8 * 3 * 2 + 2
#define NUM_LINE_VERTS (NUM_NORMAL_LINE_VERTS + 2)

/**
 获取三角形
 */
static SceneTriangle SceneTriangleMake(const SceneVertex vertexA,
                                       const SceneVertex vertexB,
                                       const SceneVertex vertexC);

/**
 返回三角形法向量
 */
static GLKVector3 SceneTriangleFaceNormal(const SceneTriangle triangle);


/**
 计算8个三角形的面法向量，然后用三角形的面法向量对每个三角形顶点的法向量进行更新。
 */
static void SceneTrianglesUpdateFaceNormals(SceneTriangle someTriangles[NUM_FACES]);

static void SceneTrianglesUpdateVertexNormals(SceneTriangle someTriangles[NUM_FACES]);

/**
 这个函数初始化了包含了8个三角形的法向量和表示光方向的线的线的顶点的值。
 */
static  void SceneTrianglesNormalLinesUpdate(const SceneTriangle someTriangles[NUM_FACES],
                                             GLKVector3 lightPosition,
                                             GLKVector3 someNormalLineVertices[NUM_LINE_VERTS]);

/**
 法线单位向量
 */
static  GLKVector3 SceneVector3UnitNormal(const GLKVector3 vectorA,
                                          const GLKVector3 vectorB);


@interface SimpleLightViewController ()<GLKViewDelegate>
{
    //八个三角形
    SceneTriangle _triangles[NUM_FACES];
}

@property (strong, nonatomic) GLKBaseEffect *baseEffect;
@property (strong, nonatomic) GLKBaseEffect *extraEffect;
@property (strong, nonatomic) AGLKVertexAttribArrayBuffer *vertexBuffer;
@property (strong, nonatomic) AGLKVertexAttribArrayBuffer *extraBuffer;

@property (assign, nonatomic) GLfloat centerVertexHeight;
@property (assign, nonatomic) BOOL shouldUseFaceNormals;
@property (assign, nonatomic) BOOL shouldDrawNormals;

@property (strong, nonatomic) GLKView *glkView;

@property (weak, nonatomic) IBOutlet UISwitch *useFaceNormalsSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *shouldDrawNormalsSwitch;
@property (weak, nonatomic) IBOutlet UISlider *centerVertexHeightSlider;
@end

@implementation SimpleLightViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    GLKView *glkView = [[GLKView alloc] init];
    glkView.frame = CGRectMake(0, 150, 375, 400);
    self.glkView = glkView;
    [self.view addSubview:glkView];
    glkView.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    glkView.delegate = self;
    [EAGLContext setCurrentContext:glkView.context];
    
    self.baseEffect = [[GLKBaseEffect alloc] init];
    self.baseEffect.light0.enabled = GL_TRUE;
    //灯光的漫反射颜色,物体的颜色由灯光决定,镜面反射和黄精颜色为GLKit的默认值,分别为不透明白色和不透明黑色
    self.baseEffect.light0.diffuseColor = GLKVector4Make(0.7f, 0.7f, 0.7f, 1.0f);
    //灯光的位置,第四个元素为零表示这是个由xyz坐标方向的平行光,否则则为一个点光源
    self.baseEffect.light0.position = GLKVector4Make(1.0f, 1.0f, 0.5f, 0.0f);
    
    _extraEffect = [[GLKBaseEffect alloc] init];
    self.extraEffect.useConstantColor = GL_TRUE;
    self.extraEffect.constantColor = GLKVector4Make(0.0f, 1.0f, 0.0f, 1.0f);
    
    {  //场景旋转,注释掉以下代码可以从上向下观察锥体
        GLKMatrix4 modelViewMatrix = GLKMatrix4MakeRotation(GLKMathDegreesToRadians(-60.0f), 1.0f, 0.0f, 0.0f);
        modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix,
                                           GLKMathDegreesToRadians(-30.0f), 0.0f, 0.0f, 1.0f);
        modelViewMatrix = GLKMatrix4Translate(modelViewMatrix,
                                              0.0f, 0.0f, 0.25f);
        
        self.baseEffect.transform.modelviewMatrix = modelViewMatrix;
        self.extraEffect.transform.modelviewMatrix = modelViewMatrix;
    }
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    
    //确定8个三角形顶点
    _triangles[0] = SceneTriangleMake(vertexA, vertexB, vertexD);
    _triangles[1] = SceneTriangleMake(vertexB, vertexC, vertexF);
    _triangles[2] = SceneTriangleMake(vertexD, vertexB, vertexE);
    _triangles[3] = SceneTriangleMake(vertexE, vertexB, vertexF);
    _triangles[4] = SceneTriangleMake(vertexD, vertexE, vertexH);
    _triangles[5] = SceneTriangleMake(vertexE, vertexF, vertexH);
    _triangles[6] = SceneTriangleMake(vertexG, vertexD, vertexH);
    _triangles[7] = SceneTriangleMake(vertexH, vertexF, vertexI);
    
    self.vertexBuffer = [[AGLKVertexAttribArrayBuffer alloc] initWithAttribStride:sizeof(SceneVertex)
                                                                 numberOfVertices:sizeof(_triangles)/sizeof(SceneVertex)
                                                                             data:_triangles
                                                                            usage:GL_DYNAMIC_DRAW];
    
    //法线
    self.extraBuffer = [[AGLKVertexAttribArrayBuffer alloc] initWithAttribStride:sizeof(SceneVertex)
                                                                numberOfVertices:0
                                                                            data:NULL
                                                                           usage:GL_DYNAMIC_DRAW];
    
    self.centerVertexHeight = 0.0f;
    self.shouldUseFaceNormals = YES;
    self.shouldDrawNormals = YES;
    
    self.useFaceNormalsSwitch.on = self.shouldUseFaceNormals;
    self.shouldDrawNormalsSwitch.on = self.shouldDrawNormals;
    self.centerVertexHeightSlider.value = self.centerVertexHeight;
}

- (void)dealloc{
    self.vertexBuffer = nil;
    self.extraBuffer = nil;
    self.glkView.context = nil;
    [EAGLContext setCurrentContext:nil];
}

#pragma mark - delegate
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    [self.baseEffect prepareToDraw];
    
    glClear(GL_COLOR_BUFFER_BIT);
    
    [self.vertexBuffer prepareToDrawWithAttrib:GLKVertexAttribPosition
                            numberOfCordinates:3
                                  attribOffset:offsetof(SceneVertex, position)
                                  shouldEnable:YES];
    
    //发送法向量给GPU
    [self.vertexBuffer prepareToDrawWithAttrib:GLKVertexAttribNormal
                            numberOfCordinates:3
                                  attribOffset:offsetof(SceneVertex, normal)
                                  shouldEnable:YES];
    
    [self.vertexBuffer drawArrayWithMode:GL_TRIANGLES
                        startVertexIndex:0
                        numberOfVertices:sizeof(_triangles) / sizeof(SceneVertex)];
    
    if(self.shouldDrawNormals){
        [self p_drawNormals];
    }
}

#pragma mark - private
/**
 画出法线和光的数量
 */
- (void)p_drawNormals
{
    GLKVector3  normalLineVertices[NUM_LINE_VERTS];
    
    // calculate all 50 vertices based on 8 triangles
    SceneTrianglesNormalLinesUpdate(_triangles,
                                    GLKVector3MakeWithArray(self.baseEffect.light0.position.v),
                                    normalLineVertices);
    
    [self.extraBuffer reinitWithAttribStride:sizeof(GLKVector3)
                            numberOfVertices:NUM_LINE_VERTS
                                       bytes:normalLineVertices];
    
    [self.extraBuffer prepareToDrawWithAttrib:GLKVertexAttribPosition
                           numberOfCordinates:3
                                 attribOffset:0
                                 shouldEnable:YES];
    
    
    //不要使用光线这样就可以展示线条的颜色
    self.extraEffect.useConstantColor = GL_TRUE;
    self.extraEffect.constantColor = GLKVector4Make(0.0, 1.0, 0.0, 1.0); // Green
    
    [self.extraEffect prepareToDraw];
    
    [self.extraBuffer drawArrayWithMode:GL_LINES
                       startVertexIndex:0
                       numberOfVertices:NUM_NORMAL_LINE_VERTS];
    
    self.extraEffect.constantColor = GLKVector4Make(1.0, 1.0, 0.0, 1.0); // Yellow
    
    [self.extraEffect prepareToDraw];
    
    [self.extraBuffer drawArrayWithMode:GL_LINES
                       startVertexIndex:NUM_NORMAL_LINE_VERTS
                       numberOfVertices:(NUM_LINE_VERTS - NUM_NORMAL_LINE_VERTS)];
}

/**
 重新计算法向量
 */
- (void)p_updateNormals
{
    if(self.shouldUseFaceNormals){
        //使用平面法向量,来产生一个平面切面的效果,使渲染出的锥体侧面是4个三角形
        SceneTrianglesUpdateFaceNormals(_triangles);
    }else{
        //利用插值
        SceneTrianglesUpdateVertexNormals(_triangles);
    }
    
    //重新渲染
    [self.vertexBuffer reinitWithAttribStride:sizeof(SceneVertex)
                             numberOfVertices:sizeof(_triangles) / sizeof(SceneVertex)
                                        bytes:_triangles];
}

#pragma mark - func
static void SceneTrianglesUpdateVertexNormals(SceneTriangle someTriangles[NUM_FACES])
{
    SceneVertex newVertexA = vertexA;
    SceneVertex newVertexB = vertexB;
    SceneVertex newVertexC = vertexC;
    SceneVertex newVertexD = vertexD;
    SceneVertex newVertexE = someTriangles[3].vertices[0];
    SceneVertex newVertexF = vertexF;
    SceneVertex newVertexG = vertexG;
    SceneVertex newVertexH = vertexH;
    SceneVertex newVertexI = vertexI;
    GLKVector3 faceNormals[NUM_FACES];
    
    // Calculate the face normal of each triangle
    for (int i=0; i<NUM_FACES; i++)
    {
        faceNormals[i] = SceneTriangleFaceNormal(someTriangles[i]);
    }
    
    //重新计算侧面四个三角的法线
    newVertexA.normal = faceNormals[0];
    newVertexB.normal = GLKVector3MultiplyScalar(GLKVector3Add(GLKVector3Add(GLKVector3Add(faceNormals[0],faceNormals[1]),faceNormals[2]),faceNormals[3]), 0.25);
    newVertexC.normal = faceNormals[1];
    newVertexD.normal = GLKVector3MultiplyScalar(GLKVector3Add(GLKVector3Add(GLKVector3Add(faceNormals[0],faceNormals[2]),faceNormals[4]),faceNormals[6]), 0.25);
    newVertexE.normal = GLKVector3MultiplyScalar(GLKVector3Add(GLKVector3Add(GLKVector3Add(faceNormals[2],faceNormals[3]),faceNormals[4]),faceNormals[5]), 0.25);
    newVertexF.normal = GLKVector3MultiplyScalar(GLKVector3Add(GLKVector3Add(GLKVector3Add(faceNormals[1],faceNormals[3]),faceNormals[5]),faceNormals[7]), 0.25);
    newVertexG.normal = faceNormals[6];
    newVertexH.normal = GLKVector3MultiplyScalar(GLKVector3Add(GLKVector3Add(GLKVector3Add(faceNormals[4],faceNormals[5]),faceNormals[6]),faceNormals[7]), 0.25);
    newVertexI.normal = faceNormals[7];
    
    //重新计算八个三角形,实际只计算了以e为顶点的四个
    someTriangles[0] = SceneTriangleMake(newVertexA, newVertexB, newVertexD);
    someTriangles[1] = SceneTriangleMake(newVertexB, newVertexC, newVertexF);
    someTriangles[2] = SceneTriangleMake(newVertexD, newVertexB, newVertexE);
    someTriangles[3] = SceneTriangleMake(newVertexE, newVertexB, newVertexF);
    someTriangles[4] = SceneTriangleMake(newVertexD, newVertexE, newVertexH);
    someTriangles[5] = SceneTriangleMake(newVertexE, newVertexF, newVertexH);
    someTriangles[6] = SceneTriangleMake(newVertexG, newVertexD, newVertexH);
    someTriangles[7] = SceneTriangleMake(newVertexH, newVertexF, newVertexI);
}

/**
 返回三角形法向量
 */
static GLKVector3 SceneTriangleFaceNormal(const SceneTriangle triangle)
{
    GLKVector3 vectorA = GLKVector3Subtract(triangle.vertices[1].position,
                                            triangle.vertices[0].position);
    GLKVector3 vectorB = GLKVector3Subtract(triangle.vertices[2].position,
                                            triangle.vertices[0].position);
    
    return SceneVector3UnitNormal(vectorA,vectorB);
}
/**
 获取三角形
 */
static SceneTriangle SceneTriangleMake(const SceneVertex vertexA,
                                       const SceneVertex vertexB,
                                       const SceneVertex vertexC){
    SceneTriangle result;
    
    result.vertices[0] = vertexA;
    result.vertices[1] = vertexB;
    result.vertices[2] = vertexC;
    
    return result;
}
/**
 这个函数初始化了包含了8个三角形的法向量和表示光方向的线的线的顶点的值。
 */
static void SceneTrianglesNormalLinesUpdate(const SceneTriangle someTriangles[NUM_FACES],
                                            GLKVector3 lightPosition,
                                            GLKVector3 someNormalLineVertices[NUM_LINE_VERTS]){
    int trianglesIndex;
    int lineVetexIndex = 0;
    
    // Define lines that indicate direction of each normal vector
    for (trianglesIndex = 0; trianglesIndex < NUM_FACES;
         trianglesIndex++)
    {
        someNormalLineVertices[lineVetexIndex++] = someTriangles[trianglesIndex].vertices[0].position;
        someNormalLineVertices[lineVetexIndex++] = GLKVector3Add(someTriangles[trianglesIndex].vertices[0].position,
                                                                 GLKVector3MultiplyScalar(someTriangles[trianglesIndex].vertices[0].normal,0.5));
        someNormalLineVertices[lineVetexIndex++] = someTriangles[trianglesIndex].vertices[1].position;
        someNormalLineVertices[lineVetexIndex++] = GLKVector3Add(someTriangles[trianglesIndex].vertices[1].position,
                                                                 GLKVector3MultiplyScalar(someTriangles[trianglesIndex].vertices[1].normal,0.5));
        someNormalLineVertices[lineVetexIndex++] = someTriangles[trianglesIndex].vertices[2].position;
        someNormalLineVertices[lineVetexIndex++] = GLKVector3Add(someTriangles[trianglesIndex].vertices[2].position,
                                                                 GLKVector3MultiplyScalar(someTriangles[trianglesIndex].vertices[2].normal,0.5));
    }
    
    // Add a line to indicate light direction
    someNormalLineVertices[lineVetexIndex++] =
    lightPosition;
    
    someNormalLineVertices[lineVetexIndex] = GLKVector3Make(0.0, 0.0, -0.5);
}
/**
 计算8个三角形的面法向量，然后用三角形的面法向量对每个三角形顶点的法向量进行更新。
 */
static void SceneTrianglesUpdateFaceNormals(SceneTriangle someTriangles[NUM_FACES])
{
    int i;
    
    for (i=0; i<NUM_FACES; i++){
        GLKVector3 faceNormal = SceneTriangleFaceNormal(someTriangles[i]);
        someTriangles[i].vertices[0].normal = faceNormal;
        someTriangles[i].vertices[1].normal = faceNormal;
        someTriangles[i].vertices[2].normal = faceNormal;
    }
}
/**
 法线单位向量
 */
GLKVector3 SceneVector3UnitNormal(const GLKVector3 vectorA,
                                  const GLKVector3 vectorB)
{
    return GLKVector3Normalize(GLKVector3CrossProduct(vectorA, vectorB));
}

#pragma mark - target

- (IBAction)changeUseFaceNormalsSwitch:(UISwitch *)sender {
    self.shouldUseFaceNormals = sender.isOn;
    [self.glkView display];
}
- (IBAction)changeShouldDrawNormalsSwitch:(UISwitch *)sender {
    self.shouldDrawNormals = sender.isOn;
    [self.glkView display];
}
- (IBAction)changeCenterVertexHeightSlider:(UISlider *)sender {
    self.centerVertexHeight = sender.value;
    [self.glkView display];
}

#pragma mark - set && get
- (void)setCenterVertexHeight:(GLfloat)centerVertexHeight{
    _centerVertexHeight = centerVertexHeight;
    SceneVertex newVertexE = vertexE;
    newVertexE.position.z = self.centerVertexHeight;
    
    //重新计算侧面的四个三角形
    _triangles[2] = SceneTriangleMake(vertexD, vertexB, newVertexE);
    _triangles[3] = SceneTriangleMake(newVertexE, vertexB, vertexF);
    _triangles[4] = SceneTriangleMake(vertexD, newVertexE, vertexH);
    _triangles[5] = SceneTriangleMake(newVertexE, vertexF, vertexH);
    
    [self p_updateNormals];
}
- (void)setShouldUseFaceNormals:(BOOL)shouldUseFaceNormals{
    
    if (_shouldUseFaceNormals != shouldUseFaceNormals) {
        _shouldUseFaceNormals = shouldUseFaceNormals;
        [self p_updateNormals];
    }
}

@end
