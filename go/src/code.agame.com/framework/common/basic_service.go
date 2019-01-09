package common

/*
	struct BasicService
	impl IService
*/
type BasicService struct {
	*RingBuffer
	id          int64
	name        string
	desc        string
}

/*
	impl IService info
*/
func (this *BasicService) GetId()int64{
	return this.id
}
func (this *BasicService) GetName()string{
	return this.name
}
func (this *BasicService) GetDesc()string{
	return this.desc
}
