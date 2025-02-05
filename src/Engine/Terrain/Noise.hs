module Engine.Terrain.Noise (
    Simplex(..), getSimplexHeight, simplexNoise,
    perm
) where

import Data.Bits ((.&.))
import System.Random.Shuffle (shuffle')
import System.Random hiding (next)
import Control.Parallel.Strategies
import qualified Data.Vector.Unboxed as V

import Graphics.Rendering.OpenGL.Raw (GLfloat)

type Permutation = V.Vector Int

-- | All the information needed to create and
--   keep track of a Simplex procedurally
--   generated terrain.
data Simplex = Simplex {
    simpSeed :: Int,
    simpDimensions :: (Int, Int),
    simpStartXY :: (Int, Int),
    simpSpacing :: GLfloat,
    simpOctaves :: Int,
    simpWavelength :: GLfloat,
    simpIntensity :: GLfloat,
    simpPerm :: Permutation
} deriving (Show, Eq)


g3 :: Double
g3 = 0.16666666666666666 -- 1/6
{-# INLINE g3 #-}

{-# INLINE int #-}
int :: Int -> Double
int = fromIntegral

grad3 :: V.Vector (Double, Double, Double)
grad3 = V.fromList [(1,1,0),(-1, 1,0),(1,-1, 0),(-1,-1, 0),
                     (1,0,1),(-1, 0,1),(1, 0,-1),(-1, 0,-1),
                     (0,1,1),( 0,-1,1),(0, 1,-1),( 0,-1,-1)]

{-# INLINE dot3 #-}
dot3 :: (Double, Double, Double) -> Double -> Double -> Double -> Double
dot3 (a,b,c) x y z = a * x + b * y + c * z

{-# INLINE fastFloor #-}
fastFloor :: Double -> Int
fastFloor x = truncate $ if x > 0 then x else x - 1

-- | Generate a random permutation for use in the noise functions
perm :: Int -> Permutation
perm seed = V.fromList . concat . replicate 2 . shuffle' [0..255] 256 $
                mkStdGen seed

-- | Generate 3D noise between -0.5 and 0.5
noise3D :: Permutation -> Double -> Double -> Double -> Double
noise3D p x y z =
    16 * (n gi0 (x0,y0,z0) + n gi1 xyz1 + n gi2 xyz2 + n gi3 xyz3)
    where
    (i,j,k) = (s x, s y, s z)
    s a = fastFloor (a + (x + y + z) / 3)
    (x0, y0, z0) = (x - int i + t, y - int j + t, z - int k + t)
    t = int (i + j + k) * g3
    (i1, j1, k1, i2, j2, k2)
        | x0 >= y0 =
            if y0 >= z0
                then (1,0,0,1,1,0)
            else if x0 >= z0
                then (1,0,0,1,0,1)
            else (0,0,1,1,0,1)
        | x0 >= y0 =
                if y0 >= z0
                    then (1,0,0,1,1,0)
                else if x0 >= z0
                    then (1,0,0,1,0,1)
                else (0,0,1,1,0,1)
        | y0 <  z0 = (0,0,1,0,1,1)
        | x0 <  z0 = (0,1,0,0,1,1)
        | otherwise = (0,1,0,1,1,0)
    xyz1 = (x0 - int i1 +   g3, y0 - int j1 +   g3, z0 - int k1 +   g3)
    xyz2 = (x0 - int i2 + 2*g3, y0 - int j2 + 2*g3, z0 - int k2 + 2*g3)
    xyz3 = (x0 - 1 + 3*g3, y0 - 1 + 3*g3, z0 - 1 + 3*g3)
    (ii,jj,kk) = (i .&. 255, j .&. 255, k .&. 255)
    gi0 = rem (V.unsafeIndex p 
        (ii + V.unsafeIndex p (jj + V.unsafeIndex p kk))) 12
    gi1 = rem (V.unsafeIndex p 
        (ii + i1 + V.unsafeIndex p (jj + j1 + V.unsafeIndex p (kk + k1)))) 12
    gi2 = rem (V.unsafeIndex p
        (ii + i2 + V.unsafeIndex p (jj + j2 + V.unsafeIndex p (kk + k2)))) 12
    gi3 = rem (V.unsafeIndex p
        (ii + 1  + V.unsafeIndex p (jj + 1  + V.unsafeIndex p (kk + 1)))) 12
    {-# INLINE n #-}
    n gi (x',y',z') = (\a -> if a < 0 then 0 else
        a*a*a*a*dot3 (V.unsafeIndex grad3 gi) x' y' z') $
            0.6 - x'*x' - y'*y' - z'*z'

harmonic :: Int -> (Double -> Double) -> Double
harmonic octaves noise = f octaves / (2 - 1 / int (2 ^ (octaves - 1)))
    where
    f 0 = 0
    f o = let r = 2 ^^ (o - 1) in noise r / r + f (o - 1)

-- | 3D simplex noise
--   args - permutation number_of_octaves wavelength x y z
simplex3D :: Permutation -> Int -> Double -> Double -> Double -> Double -> Double
simplex3D p octaves l x y z = harmonic octaves
    (\f -> noise3D p (x * f / l) (y * f / l) (z * f / l))

getSimplexHeight :: Simplex -> GLfloat -> GLfloat -> GLfloat
getSimplexHeight (Simplex _ _ _ _ octaves wavelength intensity permutation) x z =
        intensity * realToFrac
            (simplex3D permutation octaves (realToFrac wavelength)
                (realToFrac x) (realToFrac z) 0)

-- | Generate a 2D list of the height returned by simplex
--   for each coordinate.
simplexNoise :: Int -> GLfloat -> Int -> GLfloat -> GLfloat -> IO [[GLfloat]]
simplexNoise width spacing octaves wavelength intensity = do
    seed <- randomRIO (0, 100)
    let raw = map
            (\(x, y) -> intensity * realToFrac
                (simplex3D (perm seed) octaves (realToFrac wavelength) x y 0))
            [(realToFrac x, realToFrac y) |
                x <- [0, spacing .. (fromIntegral $ width-1)],
                y <- [0, spacing .. (fromIntegral $ width-1)]]
    return (splitInterval raw width `using` parChunk (width-1))

splitInterval :: [a] -> Int -> [[a]]
splitInterval xs i
    | not $ null xs =
        let (ret, rest) = splitAt i xs
        in ret : splitInterval rest i
    | otherwise = []

parChunk :: Int -> Strategy [a]
parChunk len = parListChunk (len `div` 4) r0
