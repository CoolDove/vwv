#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;

// Output fragment color
out vec4 finalColor;

void main()
{
	vec4 texelColor = texture(texture0, fragTexCoord);
	finalColor = texelColor*fragColor;
}
