package room

type Entity struct {
	ID   uint64
	Room uint64
}

type Room struct {
	ID      uint64
	Entitys map[uint64]*Entity

	Neighbor map[uint64]*Room
}

func New() {
	return &Room{Entitys: make(map[uint64]*Entity), Neighbor: make(map[uint64]*Room)}
}

func (room *Room) Enter(entity *Entity) {
	room[entity.ID] = entity
	entity.Room = room.ID
	// TODO: broad cast
}

func (room *Room) Leave(entity *Entity) {
	delete(room.Entitys, entity.ID)
	if entity.ID == room.ID {
		entity.ID = 0
	}
	// TODO: broad cast
}
