// MetalShaderSource.swift
import Foundation

/// Contains Metal shader source code as strings for runtime compilation
/// Required because SPM packages cannot use makeDefaultLibrary()
public enum MetalShaderSource {

    /// MSDF text rendering shaders
    public static let msdfShaders = """
    #include <metal_stdlib>
    using namespace metal;

    // MARK: - Data Structures

    struct VertexIn {
        float2 position [[attribute(0)]];
        float2 texCoord [[attribute(1)]];
        float4 color [[attribute(2)]];
    };

    struct VertexOut {
        float4 position [[position]];
        float2 texCoord;
        float4 color;
    };

    struct Uniforms {
        float4x4 projectionMatrix;
        float2 unitRange;  // pxRange / atlasSize
        float time;
        float padding;
    };

    struct GlyphInstance {
        float2 position;      // Screen position
        float2 size;          // Glyph size in pixels
        float4 texCoords;     // left, bottom, right, top in atlas
        float4 color;         // RGBA color
    };

    // MARK: - Vertex Shaders

    vertex VertexOut msdf_vertex(
        uint vertexID [[vertex_id]],
        uint instanceID [[instance_id]],
        constant float2 *quadVertices [[buffer(0)]],
        constant GlyphInstance *instances [[buffer(1)]],
        constant Uniforms &uniforms [[buffer(2)]]
    ) {
        GlyphInstance instance = instances[instanceID];
        float2 quadPos = quadVertices[vertexID];

        // Calculate position
        float2 position = instance.position + quadPos * instance.size;

        // Calculate texture coordinates
        float2 texCoord = mix(
            instance.texCoords.xy,  // bottom-left
            instance.texCoords.zw,  // top-right
            quadPos
        );

        VertexOut out;
        out.position = uniforms.projectionMatrix * float4(position, 0.0, 1.0);
        out.texCoord = texCoord;
        out.color = instance.color;
        return out;
    }

    // MARK: - Fragment Shaders

    /// MSDF median calculation
    float median(float r, float g, float b) {
        return max(min(r, g), min(max(r, g), b));
    }

    fragment float4 msdf_fragment(
        VertexOut in [[stage_in]],
        texture2d<float> atlas [[texture(0)]],
        constant Uniforms &uniforms [[buffer(2)]]
    ) {
        constexpr sampler atlasSampler(
            address::clamp_to_edge,
            filter::linear,
            mip_filter::linear
        );

        // Sample the MSDF atlas
        float3 sample = atlas.sample(atlasSampler, in.texCoord).rgb;

        // Calculate signed distance using median of RGB channels
        float sd = median(sample.r, sample.g, sample.b);

        // Calculate screen-space distance for anti-aliasing
        float2 screenTexSize = 1.0 / fwidth(in.texCoord);
        float screenPxRange = max(0.5 * dot(uniforms.unitRange, screenTexSize), 1.0);
        float screenPxDistance = screenPxRange * (sd - 0.5);

        // Apply smooth step for anti-aliased edge
        float alpha = clamp(screenPxDistance + 0.5, 0.0, 1.0);

        // Output color with calculated alpha
        float4 color = in.color;
        color.a *= alpha;

        // Discard fully transparent pixels
        if (color.a < 0.01) {
            discard_fragment();
        }

        return color;
    }

    // MARK: - Simple vertex shader for quad rendering

    vertex VertexOut simple_vertex(
        VertexIn in [[stage_in]],
        constant Uniforms &uniforms [[buffer(1)]]
    ) {
        VertexOut out;
        out.position = uniforms.projectionMatrix * float4(in.position, 0.0, 1.0);
        out.texCoord = in.texCoord;
        out.color = in.color;
        return out;
    }

    // MARK: - Solid color fragment (for debugging)

    fragment float4 solid_fragment(VertexOut in [[stage_in]]) {
        return in.color;
    }
    """
}
