module Engine.Object.Player where

import Data.IORef

import qualified Graphics.UI.GLFW as GLFW
import Graphics.Rendering.OpenGL.Raw

import Engine.Core.Util
import Engine.Core.Vec
import Engine.Core.World

mkPlayer :: GameObject t
mkPlayer = Player   (Vec3 0 0 0) (Vec3 0 0 0) 5
                    pUpdate
                    baseInput

pUpdate :: World t -> IO (GameObject t)
pUpdate w = do
    p <- readIORef (worldPlayer w)
    state <- readIORef (worldState w)
    let origSpeed = playerSpeed p
        speed = origSpeed * stateDelta state
        newP = p{playerSpeed = speed}
        -- Do actual update
        modifiedP = playerMouseUpdate $ playerKeyUpdate newP
        retP = modifiedP{playerSpeed = origSpeed}
        
    return retP

-- | Input for first person camera.
baseInput :: Input t
baseInput =  Input [(GLFW.Key'A, False, aIn), (GLFW.Key'D, False, dIn),
                    (GLFW.Key'W, False, wIn), (GLFW.Key'S, False, sIn),
                    (GLFW.Key'LeftShift, False, shiftIn), 
                    (GLFW.Key'Space, False, spaceIn)] (Vec2 0 0) (Vec2 0 0)

aIn :: GameObject t -> GameObject t
aIn p = moveFromLook p (Vec3 (playerSpeed p) 0 0)
dIn :: GameObject t -> GameObject t
dIn p = moveFromLook p (Vec3 (-playerSpeed p) 0 0)
wIn :: GameObject t -> GameObject t
wIn p = moveFromLook p (Vec3 0 0 (-playerSpeed p))
sIn :: GameObject t -> GameObject t
sIn p = moveFromLook p (Vec3 0 0 (playerSpeed p))

shiftIn :: GameObject t -> GameObject t
shiftIn p = moveObject p (Vec3 0 (-playerSpeed p) 0)

spaceIn :: GameObject t -> GameObject t
spaceIn p = moveObject p (Vec3 0 (playerSpeed p) 0)

-- | Takes a Player and a Vec3 of movement
--   and moves player locally based on rotation.
--   Does not use Y direction argument.
moveFromLook :: GameObject t -> Vec3 GLfloat-> GameObject t
moveFromLook player (Vec3 idx idy idz) =
    let Vec3 _ rry _ = playerRotation player
        dx = realToFrac idx
        dz = realToFrac idz
        
        ry = realToFrac rry :: Float

        mx = dx * sinDeg (ry - 90) + dz * sinDeg ry
        my = idy
        mz = dx * cosDeg (ry - 90) + dz * cosDeg ry
        
    in moveObject player $ Vec3 (realToFrac mx) my (realToFrac mz)

moveObject :: GameObject t -> Vec3 GLfloat -> GameObject t
moveObject p@(Player{}) (Vec3 dx dy dz) =
    let (Vec3 ix iy iz) = playerPosition p
        newPos = Vec3 (ix + dx) (iy + dy) (iz + dz)
    in p{playerPosition = newPos}

playerMouseUpdate :: GameObject t -> GameObject t
playerMouseUpdate player =
    let Vec2 rawdx rawdy = inputMouseDelta $ playerInput player
        Vec2 lastX lastY = inputLastMousePos $ playerInput player
        --(rawdx, rawdy) = (lastX - curX, lastY - curY)
        -- TODO: adjust multipliers
        (dxx, dy) = (rawdx*0.1, rawdy*0.1)

        --ppos = playerPosition player
        Vec3 rx ry rz = playerRotation player

        dx = -dxx

        curPos = Vec2 (lastX + rawdx) (lastY + rawdy)

        -- Basic calculation of degrees, 0 is minimum,
        -- 360 is maximum.
        newRy   
            | ry + dx >= 360 = ry + dx - 360
            | dx + ry < 0    = 360 - ry + dx
            | otherwise      = ry + dx

        -- Lowest angle player can look
        maxLookDown = -90
        -- Highest angle player can look
        maxLookUp = 90

        -- Basic calculation for x axis (looking up and down).
        -- Make sure that look direction stays between maxLookDown
        -- and maxLookUp.
        newRx
            -- If rotation is in bounds, allow rotation.
            | rx - dy >= maxLookDown && rx - dy <= maxLookUp    = rx - dy
            -- If player is trying to look down too far, set rotation to maxLookDown.
            | rx - dy < maxLookDown                             = maxLookDown
            -- If player is trying to look up too far, set rotation to maxLookUp.
            | rx - dy > maxLookUp                               = maxLookUp
            -- I don't think this will ever happen.
            | otherwise                                         = rx


        -- Update inputLastMousePos
        newInput = (playerInput player){inputLastMousePos = curPos}

        -- Return given player with modified rotation.
        newRot = Vec3 newRx newRy rz
    in player{playerRotation = newRot, playerInput = newInput}

playerKeyUpdate :: GameObject t -> GameObject t
playerKeyUpdate player=
    (playerKeyUpdateTail player){playerInput = playerInput player}

-- | Returns Player after applying all input functions.
--   UNSAFE! Returns given player with an empty inputKeys!
--   Use playerKeyUpdate instead.
playerKeyUpdateTail :: GameObject t -> GameObject t
playerKeyUpdateTail p@(Player _ _ _ _ (Input ((_, isDown, func):xs) mouse lm)) =
    -- If the key is down, apply corresponding function to player
    let newPlayer = if isDown then func p else p
        retp = newPlayer{playerInput = Input xs mouse lm}

    -- Give modified player to the function again, to recursively
    -- apply each key update.
    in playerKeyUpdateTail retp
playerKeyUpdateTail p@(Player _ _ _ _ (Input [] _ _)) = p


-- | Takes a Player and "moves the camera" by
--   moving the whole world in the opposite direction.
--   Then applies rotation.
applyTransformations :: GameObject t -> IO ()
applyTransformations player = do
    -- Not sure what it does... Basically save some
    -- current state attributes and reset those when
    -- glPopAttrib is called?
    glPushAttrib gl_TRANSFORM_BIT

    -- Rotate Player
    let Vec3 xr yr zr = playerRotation player
    glRotatef xr (-1) 0 0
    glRotatef yr 0 (-1) 0
    glRotatef zr 0 0 (-1)
    
    -- Translate Player
    let Vec3 x y z = playerPosition player
    glTranslatef (-x) (-y) (-z)

    -- Reset attributes to former state?
    glPopAttrib