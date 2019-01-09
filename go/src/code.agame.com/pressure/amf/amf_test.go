package amf


import (
	"testing"
	"bytes"
	"reflect"
)

func testU29(t *testing.T, value uint32) {
	t.Logf("test u29 0x%x", value);
	var buffer bytes.Buffer;
	if _, err := encodeU29(&buffer, value); err != nil {
		t.Fatal("Encode u29", err);
	}

	bs := buffer.Bytes();

	v, err := decodeU29(&buffer);
	if err != nil {
		t.Fatal("Decode u29", err);
	}

	if v != value {
		t.Fatalf("%x != %x %v", v, value, bs);
	}
}


func TestU29(t *testing.T) {
	testU29(t, 0);
	testU29(t, 1);
	testU29(t, 0x7f);
	testU29(t, 0x80);
	testU29(t, 0x3fff);
	testU29(t, 0x4000);
	testU29(t, 0x1fffff);
	testU29(t, 0x200000);
	testU29(t, 0x1fffffff);
	// testU29(t, 0x20000000);
}

func TestSTruct(t *testing.T) {
	type Data struct {
		Key int;
		Value struct {
			X int;
		}
	};

	var data Data;

	data.Key = 3;
	data.Value.X = 4;

	var buffer bytes.Buffer;
	if _, err := Encode(&buffer, &data); err != nil {
		t.Fatal("Encode struct", err);
	}

	bs := buffer.Bytes();

	// var xdata Data;
	// err := DecodeTo(&buffer, &xdata);
	xdata, err := Decode(&buffer); //, &xdata);
	if err != nil {
		t.Fatal("Decode struct", err);
	}

	t.Log(xdata, bs);
	// t.Fatal("xxx");
}

func testInt(t *testing.T, value int64) {
	t.Logf("test int %x", value);

	var buffer bytes.Buffer;
	if _, err := Encode(&buffer, value); err != nil {
		t.Fatal("Encode uint64", err);
	}

	bs := buffer.Bytes();

	v, err := Decode(&buffer);
	if err != nil {
		t.Fatal("Decode uint64", err);
	}

	switch v.(type) {
		case int64:
			t.Log("int64");
			if v.(int64) != value {
				t.Logf("xxxx %x, %x", value, s2u(int32(value)));
				t.Fatalf("int64 %x != %x %v", v, value, bs);
			}
		case float64:
			t.Log("float64");
			if v.(float64) != float64(value) {
				t.Fatalf("float64 %x != %x %v", v, value, bs);
			}
		default:
			t.Fatal("decode type error");
	}
}

func TestInt(t *testing.T) {
	testInt(t, 0);
	testInt(t, 3);
	testInt(t, -3);
	testInt(t, 0xfffffff);
	testInt(t, -0xfffffff);

	// out of range, double
	testInt(t, 0x10000000);
	testInt(t, -0x10000000);
}

func testDouble(t *testing.T, value float64) {
	t.Logf("test float %d", value);

	var buffer bytes.Buffer;
	if _, err := Encode(&buffer, value); err != nil {
		t.Fatal("Encode uint64", err);
	}

	bs := buffer.Bytes();

	v, err := Decode(&buffer);
	if err != nil {
		t.Fatal("Decode uint64", err);
	}

	switch v.(type) {
		case float64:
			if v.(float64) != value {
				t.Fatalf("%x != %x %v", v, value, bs);
			}
		default:
			t.Fatal("decode type error");
	}
}

func TestDouble(t *testing.T) {
	testDouble(t, 0);
	testDouble(t, 3.2);
	testDouble(t, 1002323232.2);
	testDouble(t, 3239238298229382.3);
}


func testString(t *testing.T, value string) {
	t.Logf("test string %d", value);

	var buffer bytes.Buffer;
	if _, err := Encode(&buffer, value); err != nil {
		t.Fatal("Encode string", err);
	}

	bs := buffer.Bytes();

	v, err := Decode(&buffer);
	if err != nil {
		t.Fatal("Decode string", err);
	}

	switch v.(type) {
		case string:
			if v.(string) != value {
				t.Fatalf("%s != %s %v", v, value, bs);
			}
		default:
			t.Fatal("decode type error");
	}
}


func TestString(t *testing.T) {
	testString(t, "");
	testString(t, "jflksfklsfjjfd");
	testString(t, "离开家算了疯狂积分卡洛斯将");
}


func TestAll(t *testing.T) {
	arr := make([]interface{}, 9);
	arr[0] = 1;
	arr[1] = nil;
	arr[2] = true;
	arr[3] = false;
	arr[4] = 3.5;
	arr[5] = "lskjdfksff";
	arr[6] = []byte{1,2,3,4,5};
	arr[7] = []interface{}{3, "xx"};
	arr[8] = []int{3, 4, 5};

	var buffer bytes.Buffer;
	if _, err := Encode(&buffer, arr); err != nil {
		t.Fatal("Encode", err);
	}

/*
	bs := buffer.Bytes();
	var data struct {
		V0 int;
		V1 interface{};
		V2 bool;
		V3 bool;
		V4 float64;
		V5 string;
		V6 []byte;
		V7 struct {
			V71 int;
			V72 string;
		};
	};

	err := DecodeTo(&buffer, &data);
	if err != nil {
		t.Fatal("Decode", err);
	}

	if (data.V0 != 1 ||
			data.V1 != nil ||
			data.V2 != true ||
			data.V3 != false ||
			data.V4 != 3.5 ||
			data.V5 != "lskjdfksff" ||
			data.V6[0] != 1 ||
			data.V6[1] != 2 ||
			data.V6[2] != 3 ||
			data.V6[3] != 4 ||
			data.V6[4] != 5 ||
			data.V7.V71 != 3 ||
			data.V7.V72 !="xx") {

		t.Log(bs);
		t.Log(arr);
		t.Log(data);
		t.Fatal("decode struct error");
	}
*/
	list, err := Decode(&buffer)
	if err != nil {
		t.Fatal("Decode", err);
	}
	t.Log(list)
	item_list := list.([]interface{})
	t.Log(item_list)
	for i:=0; i<len(item_list); i++ {
		it := item_list[i]
		switch it.(type) {
		case float32:
			t.Log(it.(float32))
		case float64:
			t.Log(it.(float64))
		case int:
			t.Log(it.(int))
		case int8:
			t.Log(it.(int8))
		case int16:
			t.Log(it.(int16))
		case int32:
			t.Log(it.(int32))
		case int64:
			t.Log(it.(int64))
		case uint:
			t.Log(it.(uint))
		case uint8:
			t.Log(it.(uint8))
		case uint16:
			t.Log(it.(uint16))
		case uint32:
			t.Log(it.(uint32))
		case uint64:
			t.Log(it.(uint64))
		case string:
			t.Log(it.(string))
		case []interface{}:
			t.Log(it.([]interface{}))
		default:
			ty := reflect.TypeOf(it)
			if ty != nil {
				t.Log(ty.String())
			}
		}
	}
}
