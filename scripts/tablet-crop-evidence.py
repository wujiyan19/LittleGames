"""Keep only the tested app window in public tablet screenshots."""
import sys
from PIL import Image

image = Image.open(sys.argv[1])
rectangle = tuple(int(value) for value in sys.argv[3:7])
image.crop(rectangle).save(sys.argv[2], quality=94)
