package common

import(
	"os"
	"io/ioutil"
)

/*
	func
*/
func WriteBytes(path string, content []byte)error{
	f, err := os.OpenFile(path, os.O_WRONLY, os.FileMode(0));
	if err != nil {
		return err
	}
	_, err =f.Write(content)
	f.Close()
	return err
}
func ReadBytes(path string)([]byte, error){
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	bs, err := ioutil.ReadAll(f)
	f.Close()
	return bs, err
}
func WriteString(path string, content string)error{
	return WriteBytes(path, []byte(content))
}
func ReadString(path string)(string, error){
	bs, err := ReadBytes(path)
	return string(bs), err
}
