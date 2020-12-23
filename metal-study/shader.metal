//
//  ComposePanorama.metal
//  stitching-metal
//
//  Created by idt on 2020/12/14.
//

#include <metal_stdlib>
using namespace metal;
// 输出顶点和纹理坐标，因为需要渲染纹理，可以不用输入顶点颜色
struct VertexOut
{
    float4 position [[position]];
    float2 st;
};
// 添加纹理顶点坐标
vertex VertexOut vertexShader(uint vid[[vertex_id]],
                               constant float2 *position [[ buffer(0) ]],
                               constant float2 *texCoor [[ buffer(1) ]])
{
    VertexOut outVertex;
    outVertex.position = float4(position[vid], 0.0, 1.0);
    outVertex.st = texCoor[vid];

    return outVertex;
};

fragment float4 fragmentShader(VertexOut inFrag[[stage_in]], texture2d<float> texas[[texture(0)]])
{
    constexpr sampler defaultSampler;
    float4 rgba = texas.sample(defaultSampler, inFrag.st).rgba;
    return rgba;
};

