#!/bin/env python
import pygame

pygame.init()

tilesize = 32
sliceHeight = 64
sliceWidth = 32
nSlices = 32
# textures = 0,1,3,4

terrainmap = [
  0,3,4,1
]

textures = {
  0:pygame.image.load("water.png"),
  3:pygame.image.load("land2.png"),
  4:pygame.image.load("land1.png"),
  1:pygame.image.load("land4.png")
}

last = -1
for i in range(0, len(terrainmap)):
  if last == terrainmap[i]:
    pygame.image.save(s, "output/slice"+str(i)+".png")
    continue
  s = pygame.Surface((tilesize*sliceWidth,tilesize*sliceHeight))
  texindex = terrainmap[i]
  texture = textures[texindex]
  for y in range(0,sliceHeight):
    for x in range(0, sliceWidth):
      s.blit(texture, (x*tilesize,y*tilesize))
  pygame.image.save(s, "output/slice"+str(i)+".png")
  last = texindex


