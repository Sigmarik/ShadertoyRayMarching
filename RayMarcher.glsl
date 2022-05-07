// This shader uses shadertoy uniforms, so you probably want to change them if you want to use it somewhere else.

const vec3 INF = vec3(100000.0);

// plane SDF (centre can be any point on the plane)
vec4 plane(vec3 point, vec3 centre, vec3 normal, vec3 color) {
    return vec4(color, (dot(point, normal) - dot(centre, normal)) / length(normal));
}

// Sphere SDF
vec4 sphere(vec3 point, vec3 centre, float radius, vec3 color) {
    return vec4(color, distance(point, centre) - radius);
}

vec4 myMax(vec4 a, vec4 b) {
    if (a.w > b.w) return a;
    else return b;
}

vec4 myMin(vec4 a, vec4 b) {
    if (a.w < b.w) return a;
    else return b;
}

// SDF of the whole scene.
vec4 scene(vec3 point) {
    vec4 sphereA = sphere(point, vec3(0.0, 0.0 * sin(iTime) * 5.0, -10.0), 2.0, vec3(0.2));
    vec4 roomFloor = plane(point, vec3(0.0, -5.0, 0.0), vec3(0.0, 1.0, 0.0), vec3(0.2, 0.2, 0.2));
    vec4 ceiling = plane(point, vec3(0.0, 9.0, 0.0), vec3(0.0, -1.0, 0.0), vec3(0.2, 0.2, 0.2));
    vec4 leftWall = plane(point, vec3(-9.0, 0.0, 0.0), vec3(1.0, 0.0, 0.0), vec3(0.3, 0.05, 0.05));
    vec4 rightWall = plane(point, vec3(9.0, 0.0, 0.0), vec3(-1.0, 0.0, 0.0), vec3(0.05, 0.3, 0.05));
    vec4 backWall = plane(point, vec3(0.0, 0.0, -16.0), vec3(0.0, 0.0, 1.0), vec3(0.05, 0.05, 0.3));
    vec4 frontWall = plane(point, vec3(0.0, 0.0, 13.0), vec3(0.0, 0.0, -1.0), vec3(0.3, 0.3, 0.05));
    vec4 room = myMin(myMin(myMin(ceiling, roomFloor), myMin(rightWall, leftWall)), myMin(frontWall, backWall));
    return myMin(sphereA, room);
}

// Surface normal at any point. (it basically finds gradient of SDF at the point and normalizes it)
const float normalPrecision = 0.0001;
vec3 normalAtPoint(vec3 point) {
    vec3 answer = vec3(0.0);
    answer.x = (scene(point + vec3(normalPrecision, 0.0, 0.0)).w - scene(point).w) / normalPrecision;
    answer.y = (scene(point + vec3(0.0, normalPrecision, 0.0)).w - scene(point).w) / normalPrecision;
    answer.z = (scene(point + vec3(0.0, 0.0, normalPrecision)).w - scene(point).w) / normalPrecision;
    return normalize(answer);
}

// Ray march function that returns hit location (INF if hit was not detected (disabled for now))
vec3 ray(vec3 start, vec3 direction, int quality, float minstep) {
    vec3 point = start;
    vec4 curent = vec4(0.0);
    int counter = 0;
    do {
        curent = scene(point);
        point += normalize(direction) * curent.w;
        counter += 1;
    } while (counter < quality && curent.w > minstep);
    //if (curent.w > minstep + 0.01) return INF;
    return point;
}

// There's probably built-in function for that, but anyways...
float distance2(vec3 pa, vec3 pb) {
    return (pa.x - pb.x) * (pa.x - pb.x) + (pa.y - pb.y) * (pa.y - pb.y) + (pa.z - pb.z) * (pa.z - pb.z);
}

// There's only one light source in the scene so we can chat a little and declare it with variables.
const float lightIntencity = 3.0;
const float ambientLight = 1.0;

// Function that returns color of the ray.
// start - start of the ray
// direction - directional vector of the ray
// depth - number of second-bounce rays
// screen - screen coordinates of the ray (used to generate trigonometry-based random second-bounce rays)
vec3 shade(vec3 start, vec3 direction, int depth, vec2 screen) {
    float amplitude = 2.0;

    vec3 lightPosition = vec3((iMouse.xy / iResolution.xy - 0.5) * 3.0 + vec2(0.0, 7.0), -10.0);

    vec3 hit = ray(start, direction, 1000, 0.01);
    if (distance(hit, INF) <= 0.3) return vec3(0.0);
    vec3 normal = normalAtPoint(hit);
    vec3 color = scene(hit).rgb;
    vec3 lightVector = normalize(lightPosition - hit);
    float directionalIntencity = lightIntencity * pow(0.9, distance(hit, lightPosition));
    float directionalLight = max(0.0, dot(lightVector, normal)) * directionalIntencity;

    // Blinn-Phong specular lighting. Tha-da!!!
    // (standart Phong specular might be better on scene like this. That's trial and error.)
    float bpSpecular = 1.3 * pow(max(0.0, dot(-normalize(direction - lightVector), normal)), 22.0);

    if (distance(ray(hit + normal * 0.02, lightPosition - hit, 1000, 0.01), hit) < distance(hit, lightPosition)) {
        directionalLight = 0.0;
        bpSpecular = 0.0;;
    }
    vec3 reflectedLight = vec3(0.0);
    vec2 hmul = screen * 100000.0;
    for (int rayIndex = 0; rayIndex < depth; rayIndex++) {
        float index = float(rayIndex + 1) * 30.0;
        vec3 randomRay = vec3(
            sin(index + hmul.x * 10.0), 
            cos(index + hmul.y * 50.0), 
            cos(index * 3.0 + hmul.x * 5.0 + hmul.y * 2.0));
        if (length(randomRay) <= 0.001) continue;
        randomRay = normalize(randomRay);

        //randomRay = normalize(reflect(direction, normal)) + randomRay * 0.01;  
                                      // Makes everything reflective and semi-metal. (optional)
        //randomRay += normal * 0.3;  // Directs rays to surface normals. 
                                      // May enchance visuals with low quality settings 
                                      // but will only ruin fun if high quality settings are used.
                                      // (optional)
        if (dot(randomRay, normal) < 0.0) randomRay *= -1.0;
        randomRay = normalize(randomRay);
        vec3 postHit = ray(hit + normal * 0.02, randomRay, 20, 0.01);
        vec3 postNormal = normalAtPoint(postHit);
        vec3 postColor = scene(postHit).rgb;
        vec3 postLightVector = normalize(lightPosition - postHit);
        float postDirectionalIntencity = lightIntencity * pow(0.9, distance(postHit, lightPosition));
        float postDirectionalLight = max(0.0, dot(postLightVector, postNormal)) * postDirectionalIntencity;
        if (distance(ray(postHit + postNormal * 0.02, postLightVector, 10, 0.01), postHit) < distance(postHit, lightPosition)) {
            postDirectionalLight = 0.0;
        }
        vec3 light = postColor * postDirectionalLight + postColor * ambientLight;
        light *= pow(0.95, distance(postHit, hit));

        //light *= pow(dot(postNormal, normalize(postLightVector - randomRay)), 2.2);  
                        // A little reward for rays that are closer to reflective rays. (optional)
        
        reflectedLight += abs(light);
    }
    reflectedLight /= float(depth);
    //return reflectedLight * 3.0; // Debug output :)
    return color * directionalLight + color * ambientLight + color * reflectedLight * 5.0 + color * bpSpecular;
}

const vec3 cameraPos = vec3(0.0, 0.0, 10.0);

void main() {
    vec2 uv = gl_FragCoord.xy / iResolution.xy;
    vec3 screenSpace = vec3((uv * 2.0 - 1.0) * normalize(iResolution.xy), -1.0);
    gl_FragColor = vec4(shade(cameraPos, screenSpace, 50, uv), 1.0);
}