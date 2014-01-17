module Engine.Model.AABB where

import Graphics.Rendering.OpenGL.Raw

import Engine.Core.Vec

-- | AABB (min corner) (max corner)
data AABB = AABB (Vec3 GLfloat) (Vec3 GLfloat)

-- | Takes a Vec3 containing the length, height, and width
--   and returns a Vec3 with those dimensions.
createAABB :: Vec3 GLfloat -> AABB
createAABB = AABB (Vec3 0 0 0)

moveAABB :: AABB -> Vec3 GLfloat -> AABB
moveAABB (AABB origMin origMax) deltaMovement =
    AABB (origMin + deltaMovement) (origMax + deltaMovement)

aabbDimensions :: AABB -> Vec3 GLfloat
aabbDimensions (AABB left right) = right - left

intersecting :: AABB -> AABB -> Bool
intersecting (AABB (Vec3 min1x min1y min1z) (Vec3 max1x max1y max1z))
             (AABB (Vec3 min2x min2y min2z) (Vec3 max2x max2y max2z)) =
    max1x > min2x &&
    min1x < max2x &&
    max1y > min2y &&
    min1y < max2y &&
    max1z > min2z &&
    min1z < max2z

    --- Should I do this?
    -- Haskell's ifs don't curcuit, so each test
    -- is done individually for efficiency.
    {-if max1x < min2x
        then False
    else if min1x > max2x
        then False
    else if max1y < min2y
        then False
    else if min1y > max2y
        then False
    else if max1z < min2z
        then False
    else if min1z > max2z
        then False
    else True-}