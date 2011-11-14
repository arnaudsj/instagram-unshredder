require "imlib2"
require "json"

-- Yes, right now we assume we know the width right now
local SHRED_WIDTH = 32
local imagename

if arg[1]~=nil then
   imagename = arg[1]
else
    print ("sorry, no image file was provided")
    os.exit(0)
end

-- First: Load the image that has been shredded
local image = imlib2.image.load(imagename)

if image == nil then
    print ("sorry, image file could not be loaded")
    os.exit(0)
end

local numSlices = image:get_width() / SHRED_WIDTH
local imageHeight = image:get_height()

-- Second: Let's separate the slices quickly
local slices = {}
for i=1,numSlices do
    slices[i] = image:clone()
    slices[i]:crop( (i-1)*SHRED_WIDTH, 0, SHRED_WIDTH, imageHeight)
end

-- Define the function that compares 2 slices and returns average abs delta
local right2leftdiff = function (img, img2)
    local acc, acc2 = 0, 0
    local colors = {'red', 'blue', 'green'}
    for i=1,imageHeight do
        local p1 = img:get_pixel(SHRED_WIDTH-1, i)
        local p2 = img2:get_pixel(0, i)
        for i,color in ipairs(colors) do
            local intensity = math.abs(p2[color])
            if intensity > 0 then
                acc = acc + math.abs(p1[color] - p2[color])
            end
        end
    end
    return math.abs( (acc/ (3 * imageHeight)) )
end

-- Main loop to run through all slices and calculate all the deltas
local rightmatch, leftmatch, maxscore = {}, {}, {index=0, value=0}
for j=1,#slices do
    rightmatch[j] = {}
    for i=1,#slices do
        if j ~= i then
            local score = right2leftdiff(slices[j], slices[i])
            if leftmatch[i] == nil then leftmatch[i] = {} end
            table.insert(leftmatch[i], {left = j, right = i, score = score})
            if score > maxscore.value then
                maxscore.value = score
                maxscore.index = j
            end
        end
    end
end

-- Decision call made through recursive function call
local results = {}
function unshred (sliceNum, index)
    results[sliceNum] = index
    sliceNum = sliceNum - 1
    if sliceNum>0 then
        local leftSlice =  leftmatch[index][1].left
        -- remove the slice from our results
        for i=1,#leftmatch do
            for j=1,#leftmatch[i] do
                if leftmatch[i][j] ~= nil and leftmatch[i][j].left == index then
                    table.remove(leftmatch[i], j)
                end
            end
            table.sort(leftmatch[i], function(a,b) return a.score < b.score end)
        end
        unshred(sliceNum, leftSlice)
    end
end
unshred(numSlices, maxscore.index, 0)

-- We're almost done, let's rebuild the unshredded image now
for i=1,#results do
    local slice2copy = slices[ results[i] ]
    for x=0,SHRED_WIDTH-1 do
        for y=0,imageHeight do
            image:draw_pixel( (i-1)*SHRED_WIDTH + x, y, slice2copy:get_pixel(x, y))
        end
    end
end

-- Save the resulting image
image:save("result.png")
print("image saved as result.png")







