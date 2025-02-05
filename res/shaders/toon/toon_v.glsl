#version 430

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec2 texCoord;
layout(location = 3) in vec3 color;
layout(location = 4) in float textureId;
layout(location = 5) uniform mat4 projectionMatrix;
layout(location = 6) uniform mat4 viewMatrix;
layout(location = 7) uniform mat4 modelMatrix;
layout(location = 8) uniform mat4 mvpMatrix;

out vec3 fragColor;
out vec3 vertex;
out vec2 textureCoord;
out vec3 norm;
out flat int texId;

void main()
{
    vertex = position;
    textureCoord = texCoord;
    norm = normal;
    fragColor = color;
    texId = int(textureId);

    gl_Position = mvpMatrix * vec4(position, 1.0);
}
