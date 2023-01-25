#ifndef CG_MATHS
#define CG_MATHS

//Definitions for pi and 2*pi
#define S_PI 3.14159265359f
#define S_TWO_PI 6.28318530718f

    //Creates a rotation matrix
    float3x3 GetRotationMatrix(float angle, float3 axis)
    {
        //Get the sin, cos and theta of the angle
        float angleCos;
        float angleSin;
        sincos(angle, angleSin, angleCos);
        float theta = 1 - angleCos;

        ///Just to make creation of the matrix more readable
        float x = axis.x;
        float y = axis.y;
        float z = axis.z;

        //Standard creation of a rotation matrix
        return float3x3
            (
                theta * x * x + angleCos,               theta * x * y - angleSin * z,       theta * x * z + angleSin * y,
                theta * x * y + angleSin * z,           theta * y * y + angleCos,           theta * y * z - angleSin * x,
                theta * x * z - angleSin * y,           theta * y * z + angleSin * x,       theta * z * z + angleCos
            );
    }

    //Noise function to create a random number between 0 and 1 using a position as the seed
    //from http://answers.unity.com/answers/624136/view.html
    float rand(float3 seed)
    {
        return frac(sin(dot(seed.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
    }

#endif