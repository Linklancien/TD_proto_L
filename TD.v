import gg

const win_width = 601
const win_height = 601
const bg_color = gg.Color{
	r: 0
	g: 200
	b: 0
}

struct App {
mut:
	gg &gg.Context = unsafe { nil }
	frame_count int
	map Map
}

struct Map {
	ennemi_spawn [][]f32
	circuits [][][]f32
mut:
	projectiles []Projectile
	tours []Tower
	ennemis []Ennemi
	pv int
	placing_mode bool
	can_place bool
}

struct Ennemi {
	circuit int
mut:
	pos_xy []f32
	pos_relatif int
	pv int
}

struct Tower {
	radius int
	range int
	degats int
	pos []int
mut:
	cooldown int = 60
}

struct Projectile {
	radius int
	vitesse int
	degats int
mut:
	pos []f32
	life_span int
	vecteur_directeur []f32
}


fn main() {
	mut app := &App{}
	app.gg = gg.new_context(
		width: win_width
		height: win_height
		create_window: true
		window_title: 'TD.v'
		user_data: app
		fullscreen: true
		bg_color: bg_color
		frame_fn: on_frame
		event_fn: on_event
		sample_count: 2
	)
	app.map = Map {ennemi_spawn: [[f32(0), f32(384)]], circuits: [][][]f32{len: 1, init: [][]f32{len: 2760, init: [index / f32(2), f32(384)]}}}

	// lancement du programme/de la fenêtre
	app.gg.run()
}

fn on_frame(mut app App) {
	app.frame_count += 1
	if app.frame_count % 60  == 0 {
		app.map.ennemis << Ennemi{pos_xy: app.map.ennemi_spawn[0].clone(), pos_relatif: 0, circuit: 0}
	}
	
	mut distance_min := f32(90 * 90)
	for circuit in app.map.circuits {
		for point_circuit in circuit {
			if (point_circuit[0] - app.gg.mouse_pos_x) * (point_circuit[0] - app.gg.mouse_pos_x) + (point_circuit[1] - app.gg.mouse_pos_y) * (point_circuit[1] - app.gg.mouse_pos_y) < distance_min {
				distance_min = (point_circuit[0] - app.gg.mouse_pos_x) * (point_circuit[0] - app.gg.mouse_pos_x) + (point_circuit[1] - app.gg.mouse_pos_y) * (point_circuit[1] - app.gg.mouse_pos_y)
			}
		}
	}
	if distance_min < 90 * 90 {
		app.map.can_place = false
	} else {
		app.map.can_place = true
	}
	
	mut projectile_delete_indexes := []int{}
	for mut projectile in app.map.projectiles {
		projectile.pos[0] += projectile.vecteur_directeur[0]
		projectile.pos[1] += projectile.vecteur_directeur[1]
		projectile.life_span -= 1
		if projectile.life_span <= 0 {
			projectile_delete_indexes << app.map.projectiles.index(projectile)
		}
	}
	for projectile_delete_index in projectile_delete_indexes {
		app.map.projectiles.delete(projectile_delete_index)
	}
	
	// Draw
	app.gg.begin()
	app.gg.draw_rect_filled(0, 2 * app.gg.window_size().height/5, app.gg.window_size().width, app.gg.window_size().height/5, gg.Color{r: 217, g: 186, b: 111})
	mut indexes := []int{}
	for mut ennemi in app.map.ennemis {
		app.gg.draw_circle_filled(ennemi.pos_xy[0], ennemi.pos_xy[1], 10, gg.Color{r: 255})
		if ennemi.pos_relatif < app.map.circuits[ennemi.circuit].len - 1 {
			ennemi.pos_relatif, ennemi.pos_xy =  ennemi.move(app.map.circuits[ennemi.circuit])
		} else {
			indexes << app.map.ennemis.index(ennemi)
		}
	}
	for index in indexes {
		app.map.ennemis.delete(index)
	}
	if app.map.placing_mode {
		if app.map.can_place {
			app.gg.draw_circle_filled(app.gg.mouse_pos_x, app.gg.mouse_pos_y, 10, gg.Color{r: 103, g: 103, b: 103, a: 150})
			app.gg.draw_circle_filled(app.gg.mouse_pos_x, app.gg.mouse_pos_y, 100, gg.Color{r: 103, g: 103, b: 103, a: 50})
		} else {
			app.gg.draw_circle_filled(app.gg.mouse_pos_x, app.gg.mouse_pos_y, 10, gg.Color{r: 228, g: 103, b: 103, a: 150})
			app.gg.draw_circle_filled(app.gg.mouse_pos_x, app.gg.mouse_pos_y, 100, gg.Color{r: 220, g: 103, b: 103, a: 50})
		}
	}
	for mut tour in app.map.tours {
		if tour.cooldown > 0 {
			tour.cooldown -= 1
		}
		app.gg.draw_circle_filled(tour.pos[0], tour.pos[1], tour.radius, gg.Color{r: 103, g: 103, b: 103})
		app.gg.draw_circle_filled(tour.pos[0], tour.pos[1], tour.range, gg.Color{r: 103, g: 103, b: 103, a: 100})
		for ennemi in app.map.ennemis {
			if tour.detect(ennemi) && tour.cooldown == 0 {
				tour.cooldown = 60
				app.map.projectiles << Projectile{radius: 2, pos: [f32(tour.pos[0]), f32(tour.pos[1])], vitesse: 750, life_span: 120}
				app.map.projectiles[app.map.projectiles.len - 1].vecteur_directeur = app.map.projectiles[app.map.projectiles.len - 1].find_vector(ennemi, app.map.circuits[ennemi.circuit])
			}
		}
	}
	for projectile in app.map.projectiles {
		app.gg.draw_circle_filled(projectile.pos[0], projectile.pos[1], projectile.radius, gg.Color{})
	}
	app.gg.show_fps()
	app.gg.end()
}

fn on_event(e &gg.Event, mut app App) {
	match e.typ {
		.key_down {
			match e.key_code {
				.p {
					if !app.map.placing_mode {
						app.map.placing_mode = true
					} else {
						app.map.placing_mode = false
					}
				}
				.escape {
					app.gg.quit()
				}
				else {}
			}
		}
		.key_up {
			match e.key_code {
				.enter {
					if app.map.placing_mode && app.map.can_place {
						app.map.tours << Tower{radius:10, pos: [app.gg.mouse_pos_x, app.gg.mouse_pos_y], range: 100}
					}
				}
				else {}
			}
		}
		else {}
	}
}

fn (e Ennemi) move (circuit [][]f32) (int, []f32) {
	return e.pos_relatif + 1, circuit[e.pos_relatif + 1].clone()
}

fn (t Tower) detect (ennemi Ennemi) bool {
	mut detection := false
	if (ennemi.pos_xy[0] - t.pos[0]) * (ennemi.pos_xy[0] - t.pos[0]) + (ennemi.pos_xy[1] - t.pos[1]) * (ennemi.pos_xy[1] - t.pos[1]) <= t.range * t.range {
		detection = true
	}
	return detection
}

fn (p Projectile) find_vector (ennemi Ennemi, circuit[][]f32) []f32 {
	norme := (circuit[ennemi.pos_relatif][0] - p.pos[0]) * (circuit[ennemi.pos_relatif][0] - p.pos[0]) + (circuit[ennemi.pos_relatif][1] - p.pos[1]) * (circuit[ennemi.pos_relatif][1] - p.pos[1])
	return [((circuit[ennemi.pos_relatif][0] - p.pos[0]) / norme) * p.vitesse, ((circuit[ennemi.pos_relatif][1] - p.pos[1]) / norme) * p.vitesse]
}

//fn (p Projectile) move () []int {
	
//}

fn min(x int, y int) int {
	if x >= y {
		return y
	} else {
		return x
	}
}