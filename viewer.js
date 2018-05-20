// Demo https://codepen.io/deltabouche/full/WJPbaQ/

// Requires p5.js and lodash

const MapBase = "http://localhost:3000/";

const Maps = [
  "0-Intro",
  "1-ForsakenCity",
  "1H-ForsakenCity",
  "1X-ForsakenCity",
  "2-OldSite",
  "2H-OldSite",
  "2X-OldSite",
  "3-CelestialResort",
  "3H-CelestialResort",
  "3X-CelestialResort",
  "4-GoldenRidge",
  "4H-GoldenRidge",
  "4X-GoldenRidge",
  "5-MirrorTemple",
  "5H-MirrorTemple",
  "5X-MirrorTemple",
  "6-Reflection",
  "6H-Reflection",
  "6X-Reflection",
  "7-Summit",
  "7H-Summit",
  "7X-Summit",
  "8-Epilogue",
  "9-Core",
  "9H-Core",
  "9X-Core"
]

let state = {
  mapPath: "0-Intro",
  dataReady: false,
  camera: {
    x: 200,
    y: 200,
    scale: 1
  },
  levelCamera: {
    x: 5,
    y: 5
  },
  screen: {
    width: 1280,
    height: 720
  },
  map: null,
  thumbnails: [],
  levelIndex: -1,
  hoverLevel: -1
};

const SolidColors = {
  "0": "#000000", //0
  "1": "#FF0000", //1
  "2": "#00FF00", //2
  "3": "#0000FF", //3
  "4": "#FF00FF", //4 
  "5": "#FFFF00", //5
  "6": "#00FFFF", //6
  "7": "#888888", //7
  "g": "#FF00FF"
};

function setupThumbnails() {
  const levels = childByName(state.map.root, 'levels');
  let visIndex = 0;
  _.each(levels.children, (lvl, lvlIndex) => {
    let pg = createGraphics(lvl.attributes.width, lvl.attributes.height);
    const solids = childrenByName(lvl, 'solids');
    _.each(solids, solid => {
      let tx = 0;
      let ty = 0;
      _.each(solid.attributes.innerText, v => {
        if (v == 10) {
          ty++;
          tx=0;
          return;
        }
        const tRect = {
          x: solid.attributes.offsetX + tx * 8 + 1,
          y: solid.attributes.offsetY + ty * 8 + 1,
          width: 7,
          height: 7
        }
        pg.noStroke();
        const color = SolidColors[String.fromCharCode(v)] || 200;
        pg.fill(color);
        pg.rect(tRect.x / 2, tRect.y/ 2, tRect.width/ 2, tRect.height/ 2);
        tx++;
      });
    });
    state.thumbnails.push(pg)
  });
}

function resetCamera() {
  state.camera = { x: 200, y: 200, scale: 0.5 };
}

function resetLevelCamera() {
  state.levelCamera = { x: 5, y: 5 };
}

function loadMap(path) {
  state.dataReady = false;
  state.thumbnails = [];
  state.map = null;
  state.mapPath = path;
  state.levelIndex = -1;
  fetch(`${MapBase}/${state.mapPath}.json`).then(res => res.json()).then(json => {
    state.map = json;
    setupThumbnails();
    state.dataReady = true;
    addLevelSelect();
    resetCamera();
  })
}

function loadLevel(idx) {
  if (idx >= 0) resetLevelCamera();
  state.levelIndex = parseInt(idx, 10);
}

function setup() {
  addMapSelect();
  let canvasElement = createCanvas(state.screen.width, state.screen.height).elt;
  canvasElement.addEventListener('contextmenu', event => { event.preventDefault(); });
  let context = canvasElement.getContext('2d');
  context.mozImageSmoothingEnabled = false;
  context.webkitImageSmoothingEnabled = false;
  context.msImageSmoothingEnabled = false;
  context.imageSmoothingEnabled = false;
  loadMap(state.mapPath);
}

function childrenByName(el, name) {
  return _.filter(el.children, { name });
}

function childByName(el, name) {
  return _.find(el.children, { name });
}

function drawAxes() {
  stroke("#0000FF");
  line(state.camera.x, 0, state.camera.x, state.screen.height);
  line(0, state.camera.y, state.screen.width, state.camera.y);
}

function drawHeadings() {
  text(state.map.root.package, 20, 20);
}

function screenTransformRect(rect) {
  return {
    x: rect.x * state.camera.scale + state.camera.x,
    y: rect.y * state.camera.scale + state.camera.y,
    width: rect.width * state.camera.scale,
    height: rect.height * state.camera.scale
  }
}

function screenLevelTransformRect(rect) {
  return {
    x: (rect.x + state.levelCamera.x * 8) * 2,
    y: (rect.y + state.levelCamera.y * 8) * 2,
    width: rect.width * 2,
    height: rect.height * 2    
  }
}

function pointInRect(x, y, rect) {
  return x > rect.x && x < rect.x + rect.width && y > rect.y && y < rect.y + rect.height;
}

function rectIsVisible(rect) {
  return rect.x + rect.width > 0 && rect.y + rect.height > 0 && rect.x < state.screen.width && rect.y < state.screen.height
}

function drawFillers() {
  const fillers = childByName(state.map.root, 'Filler');
  _.each(fillers.children, (fillRect) => {
    const drawRect = screenTransformRect({
      x: fillRect.attributes.x * 8,
      y: fillRect.attributes.y * 8,
      width: fillRect.attributes.w * 8,
      height: fillRect.attributes.h * 8
    });
    if (!rectIsVisible(drawRect)) return;
    stroke("#FF0000");
    fill("#330000");
    rect(drawRect.x, drawRect.y, drawRect.width, drawRect.height);
  });
}

function drawLevels() {
  const levels = childByName(state.map.root, 'levels');
  let visIndex = 0;
  _.each(levels.children, (lvl, lvlIndex) => {
    fill(255);
    stroke(255);
    const drawRect = screenTransformRect(lvl.attributes);
    if (!rectIsVisible(drawRect)) return;
    // text(`${drawRect.x}, ${drawRect.y}, ${drawRect.width}, ${drawRect.height}`, 10, 80 + 20 * visIndex);
    visIndex++;
    image(state.thumbnails[lvlIndex], drawRect.x, drawRect.y, drawRect.width, drawRect.height);
    noFill();
    if (pointInRect(mouseX, mouseY, screenTransformRect(lvl.attributes))) {
      text(lvl.attributes.name, 10, 80);
      stroke(255); 
      state.hoverLevel = lvlIndex;
    } else {
      stroke(64);
    }
    rect(drawRect.x, drawRect.y, drawRect.width, drawRect.height);
  });
}

function processInput() {
  if (state.levelIndex === -1) {
    if (keyIsDown(LEFT_ARROW)) {
      state.camera.x += 8;
    }
    if (keyIsDown(RIGHT_ARROW)) {
      state.camera.x -= 8;
    }
    if (keyIsDown(UP_ARROW)) {
      state.camera.y += 8;
    }

    if (keyIsDown(DOWN_ARROW)) {
      state.camera.y -= 8;
    }
  } else {
    if (keyIsDown(LEFT_ARROW)) {
      state.levelCamera.x += 1;
    }
    if (keyIsDown(RIGHT_ARROW)) {
      state.levelCamera.x -= 1;
    }
    if (keyIsDown(UP_ARROW)) {
      state.levelCamera.y += 1;
    }

    if (keyIsDown(DOWN_ARROW)) {
      state.levelCamera.y -= 1;
    }    
  }
}

function keyPressed() {
  if (keyCode === 81) {
    state.camera.x *= 1.5;
    state.camera.y *= 1.5;
    state.camera.scale *= 1.5;
  }
  if (keyCode === 65) {
    state.camera.x /= 1.5;
    state.camera.y /= 1.5;
    state.camera.scale /= 1.5;
  }
  if (keyCode === 27) {
    let select = document.getElementById('level-select');
    select.value = -1;
    loadLevel(-1);
  }
}

function mousePressed() {
  if (mouseButton === RIGHT) {
    if (state.hoverLevel >= 0) {
       let idx = state.hoverLevel;
       state.hoverLevel = -1;
       let select = document.getElementById('level-select');
       select.value = idx;
       loadLevel(idx);  
    }
  }
}

function drawHud() {
  text(`${mouseX}, ${mouseY}`, 10, 50);
}

function drawLoading() {
  text("Loading...", state.screen.width / 2, state.screen.height / 2);
}

function drawOverview() {
  drawAxes();
  drawHud();
  drawHeadings();
  drawFillers();
  drawLevels();
}

function drawLevel() {
  const levels = childByName(state.map.root, 'levels');
  const level = levels.children[state.levelIndex];

  // draw surrounding levels
  _.each(levels.children, (sLevel, i) => {
    if (i == state.levelIndex) return;
    const drawRect = screenLevelTransformRect({
      x: sLevel.attributes.x - level.attributes.x,
      y: sLevel.attributes.y - level.attributes.y,
      width: sLevel.attributes.width,
      height: sLevel.attributes.height
    });
    if (!rectIsVisible(drawRect)) return;
    if (pointInRect(mouseX, mouseY, drawRect)) {
      stroke(128, 128, 128, 255);
      tint(255, 192);
      state.hoverLevel = i;
    } else {
      stroke(128, 128, 128, 128);
      tint(255, 128);
    }
    image(state.thumbnails[i], drawRect.x, drawRect.y, drawRect.width, drawRect.height);
    noFill();
    rect(drawRect.x, drawRect.y, drawRect.width, drawRect.height);
    tint(255, 255);
  });
  
  
  // noFill(64);
  // rect((state.levelCamera.x * 16) + 16, (state.levelCamera.y * 16) + 16, level.attributes.width * 2, level.attributes.height * 2);

  const solids = childByName(level, 'solids');
  const solidMap = solids.attributes.innerText;
  let tx = 0;
  let ty = 0;

  const levelDrawRect = screenLevelTransformRect({
    x: 0,
    y: 0,
    width: level.attributes.width,
    height: level.attributes.height
  })

  image(state.thumbnails[state.levelIndex], levelDrawRect.x, levelDrawRect.y, levelDrawRect.width, levelDrawRect.height);

//   _.each(solidMap, (v, i) => {
//     if (v === 10) {
//       ty++;
//       tx=0;
//       return;
//     }
//     const drawRect = screenLevelTransformRect({
//       x: tx * 8,
//       y: ty * 8,
//       width: 8,
//       height: 8
//     })
//     tx++;
//     if (!rectIsVisible(drawRect)) return;
    
//     stroke(32);

//     // const color = SolidColors[String.fromCharCode(v)] || 200;
//     // fill(color);
   

//     // rect(drawRect.x, drawRect.y, drawRect.width, drawRect.height);
//     fill(0);
//     text(String.fromCharCode(v), drawRect.x + 6, drawRect.y + 12);
//   });
  
  const entities = childByName(level, 'entities');
  _.each(entities.children, entity => {
    const drawRect = screenLevelTransformRect({
      x: entity.attributes.x - (entity.attributes.originX || 0),
      y: entity.attributes.y - (entity.attributes.originY || 0),
      width: entity.attributes.width || 8,
      height: entity.attributes.height || 8
    })
    if (!rectIsVisible(drawRect)) return;
    stroke(255, 255, 255, 128);
    fill(255, 255, 255, 128);
    text(entity.name, drawRect.x, drawRect.y);
    stroke(255, 64, 64, 128);
    fill(64, 0, 0, 128);
    rect(drawRect.x, drawRect.y, drawRect.width, drawRect.height);
  })
  stroke(128);
  noFill();
  rect(levelDrawRect.x, levelDrawRect.y, levelDrawRect.width, levelDrawRect.height);
}

function draw() {
  processInput();
  background(0);
  stroke(255);
  fill(255);
  if (state.dataReady) {
    if (state.levelIndex === -1) {
      drawOverview();
    } else {
      drawLevel();
    }
  } else {
    drawLoading();
  }
}

function addMapSelect() {
  let mapSelectContainer = document.getElementById("map-select-container");
  let selectList = document.createElement("select");
  selectList.id = "map-select";
  mapSelectContainer.appendChild(selectList);
  _.each(Maps, mapName => {
    let option = document.createElement("option");
    option.value = mapName;
    option.text = mapName;
    selectList.appendChild(option);  
  })
  selectList.addEventListener('change', function(){
    loadMap(this.value);
  });
}

function addLevelSelect() {
  let levelSelectContainer = document.getElementById("level-select-container");
  levelSelectContainer.innerHTML = "";
  let selectList = document.createElement("select");
  selectList.id = "level-select";
  levelSelectContainer.appendChild(selectList);
  let defOption = document.createElement("option");
  defOption.value = -1;
  defOption.text = "Overview";
  selectList.appendChild(defOption);
  const levels = childByName(state.map.root, 'levels');
  _.each(levels.children, (lvl, idx) => {
    let option = document.createElement("option");
    option.value = idx;
    option.text = lvl.attributes.name;
    selectList.appendChild(option);  
  })
  selectList.addEventListener('change', function(){
    loadLevel(this.value);
  });
}