module Engine.Graphics.GraphicsUtils (
    createBufferIdAll, createBufferId,
    fillNewBuffer, withNewPtr, withNewPtrArray,
    useNewPtr, offsetPtr, offset0
) where

import Foreign
    (Ptr, Storable, withArrayLen, sizeOf,
     alloca, peek, peekArray, wordPtrToPtr)

import Graphics.Rendering.OpenGL.Raw
    (GLuint, GLfloat, glGenVertexArrays,
     glBindVertexArray, glGenBuffers,
     glBindBuffer, gl_ARRAY_BUFFER,
     glBufferData, gl_STATIC_DRAW)

-- | Create an id for each buffer data.
createBufferIdAll :: [[GLfloat]] -> IO [GLuint]
createBufferIdAll (cur:others) = do
    currentId <- createBufferId cur
    otherId <- createBufferIdAll others
    return $ currentId:otherId
createBufferIdAll [] = return []

-- | Create a buffer id for the information.
createBufferId :: [GLfloat] -> IO GLuint
createBufferId info = do
    vertexArrayId <- withNewPtr (glGenVertexArrays 1)
    glBindVertexArray vertexArrayId
    fillNewBuffer info

-- | Fill buffer with data.
fillNewBuffer :: [GLfloat] -> IO GLuint
fillNewBuffer list = do
    bufId <- withNewPtr (glGenBuffers 1)
    glBindBuffer gl_ARRAY_BUFFER bufId
    withArrayLen list $ \len ptr ->
        glBufferData gl_ARRAY_BUFFER
            (fromIntegral (len * sizeOf (undefined :: GLfloat)))
            (ptr :: Ptr GLfloat) gl_STATIC_DRAW
    return bufId

-- | Perform IO action with a new pointer, returning the
--   value in the pointer.
withNewPtr :: Storable b => (Ptr b -> IO a) -> IO b
withNewPtr f = alloca (\p -> f p >> peek p)

-- | Perform IO action with a new pointer array, returning the
--   value in the pointer.
withNewPtrArray :: Storable b => (Ptr b -> IO a) -> Int -> IO [b]
withNewPtrArray f size = alloca (\p -> f p >> peekArray size p)

-- | Perform IO action with a new pointer, returning the
--   pointer itself.
useNewPtr :: Storable a => (Ptr a -> IO a1) -> IO (Ptr a)
useNewPtr f = alloca (\p -> f p >> return p)

-- | Produce a 'Ptr' value to be used as an offset of the given number
--   of bytes.
offsetPtr :: Int -> Ptr a
offsetPtr = wordPtrToPtr . fromIntegral

-- | A zero-offset 'Ptr'.
offset0 :: Ptr a
offset0 = offsetPtr 0
