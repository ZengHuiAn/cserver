package main

import (
	"sync"
	"container/list"
)


type element struct {
	tag int;
	data interface{};
}

type Queue struct {
	lock sync.Mutex;
	list *list.List;
}

func New() *Queue {
	return &Queue{list:list.New()}
}

func (q*Queue) Push(tag int, data interface{}) {
	q.lock.Lock();
	defer q.lock.Unlock();

	q.list.PushBack(&element{tag:tag, data:data});
}

func (q*Queue)Pop(tags ... int) interface{} {
	q.lock.Lock();
	defer q.lock.Unlock();

	for e := q.list.Front(); e != nil; e = e.Next() {
		data := e.Value.(*element);
		for i := 0; i < len(tags); i++ {
			if data.tag == tags[i] {
				q.list.Remove(e);
				return data.data;
			}
		}
	}
	return nil;
}
