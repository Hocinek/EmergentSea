shader_type canvas_item;

void fragment() {
    vec2 uv = UV * 2.0 - 1.0; // centre sur (0,0)

    // Forme hexagonale adaptée à ta map
    uv = abs(uv);

    float edge = max(
        uv.x * 0.8660254 + uv.y * 0.5, // cos(30), sin(30)
        uv.y
    );

    vec4 tex = texture(TEXTURE, UV);

    // Coupe nette hors de l'hexagone
    if (edge > 0.8660254) {
        discard;
    }

    COLOR = tex;
}