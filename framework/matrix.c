#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "matrix.h"

struct  MatrixField
{
	char * value;
};

struct MatrixRow 
{
	size_t count;
	size_t alloced;
	MatrixField ** field;
};

struct Matrix {
	size_t count;
	size_t alloced;
	MatrixRow ** row;
};

static MatrixField * MatrixFieldNew(const char * msg, size_t len)
{
	MatrixField * field = (MatrixField*)malloc(sizeof(MatrixField));
	field->value = (char*)malloc(len + 1);
	memcpy(field->value, msg, len);
	field->value[len] = 0;
	return field;
}

static void MatrixFieldFree(MatrixField * field)
{
	free(field->value);
	free(field);
}

static void MatrixRowResize(MatrixRow * row)
{
	if (row->count < row->alloced) {
		return;
	}

	size_t new_alloc = 0;
	if (row->alloced == 0) {
		new_alloc = 32;	
	} else {
		new_alloc = row->alloced * 2;
	}

	row->field = (MatrixField**)realloc(row->field, sizeof(MatrixField*) * new_alloc);

	size_t i;
	for(i = row->count; i < new_alloc; i++) {
		row->field[i] = 0;
	}

	row->alloced = new_alloc;
}

static MatrixRow *  MatrixRowNew()
{
	MatrixRow * row = (MatrixRow*)malloc(sizeof(MatrixRow));
	row->alloced = 0;
	row->count = 0;
	row->field = 0;
	return row;
}

static void MatrixRowPush(MatrixRow * row, MatrixField * field)
{
	MatrixRowResize(row);
	assert(row->count < row->alloced);
	row->field[row->count++] =  field;
}

static void MatrixRowFree(MatrixRow * row)
{
	size_t i;
	for(i = 0; i < row->count; i++) {
		MatrixFieldFree(row->field[i]);
	}
	free(row->field);
	free(row);
}

static void MatrixResize(Matrix * matrix)
{
	if (matrix->count < matrix->alloced) {
		return;
	}

	size_t new_alloc = 0;
	if (matrix->alloced == 0) {
		new_alloc = 32;	
	} else {
		new_alloc = matrix->alloced * 2;
	}

	matrix->row = (MatrixRow**)realloc(matrix->row, sizeof(MatrixRow*) * new_alloc);

	size_t i;
	for(i = matrix->count; i < new_alloc; i++) {
		matrix->row[i] = 0;
	}

	matrix->alloced = new_alloc;
}

static Matrix *  MatrixNew()
{
	Matrix * matrix = (Matrix*)malloc(sizeof(Matrix));
	matrix->alloced = 0;
	matrix->count = 0;
	matrix->row = 0;
	return matrix;
}

static void MatrixPush(Matrix * matrix, MatrixRow * row)
{
	MatrixResize(matrix);
	assert(matrix->count < matrix->alloced);
	matrix->row[matrix->count++] = row;
}

void MatrixFree(Matrix * matrix)
{
	size_t i;
	for(i = 0; i < matrix->count; i++) {
		MatrixRowFree(matrix->row[i]);
	}
	free(matrix->row);
	free(matrix);
}

Matrix * LoadMatrix(const char * filename, char sep_field, char sep_row)
{
	Matrix * matrix = MatrixNew();
	if (matrix == 0) {
		return 0;
	}


	FILE * file = fopen(filename, "r");
	if (file == 0) {
		MatrixFree(matrix);
		return 0;
	}

	MatrixRow * cur_row = MatrixRowNew();

	//MatrixPush(matrix, cur_row);

	char buff[4096] = {0};
	size_t len = 0;
	char * ptr = buff;
	size_t strlen = 0;
	while(!feof(file)) {
		len += fread(buff + len, 1, sizeof(buff) - len, file);

		//从头找
		ptr = buff;
		strlen = 0;

		size_t i;
		for(i = 0; i < len; i++) {
			if (buff[i] == sep_field || buff[i] == sep_row) {
				MatrixField * field = MatrixFieldNew(ptr, strlen);
				MatrixRowPush(cur_row, field);
				ptr = buff + i + 1;
				strlen = 0;
				if (buff[i] == sep_row) {
					if (cur_row->count > 0) {
						MatrixPush(matrix, cur_row);
						cur_row = MatrixRowNew();
					}
					ptr = buff + i + 1;
					strlen = 0;
				}
			} else {
				strlen++;
			}
		}

		if (ptr != buff + len) {
			len -=  ptr - buff;
			memmove(buff, ptr, len);
			ptr = buff;
		} else {
			len = 0;
		}
	}

	if (ptr && strlen > 0) {
		MatrixRowPush(cur_row, MatrixFieldNew(ptr, strlen));		
	}

	if (cur_row->count > 0) {
		MatrixPush(matrix, cur_row);
	} else {
		MatrixRowFree(cur_row);
	}

	fclose(file);
	return matrix;
}

size_t MatrixSize(Matrix * matrix)
{
	return matrix->count;	
}

MatrixRow * MatrixGet(Matrix * matrix, size_t row)
{
	if (row >= matrix->count) {
		return 0;
	}
	return matrix->row[row];
}

size_t MatrixRowSize(MatrixRow * row)
{
	return row->count;
}

MatrixField * MatrixRowGet(MatrixRow * row, size_t field)
{
	if (field >= row->count) {
		return 0;
	}
	return row->field[field];
}

const char * MatrixFieldValue(MatrixField * field)
{
	return field->value;
}

#if 0
int main(int argc, char * argv[])
{
	int i;
	for(i = 1; i < argc; i++) {
		printf(" === %s ===\n", argv[i]);
		Matrix * matrix = LoadMatrix(argv[i], ',', '\n');
		if (matrix == 0) {
			continue;
		}
		size_t x, y;
		for(y = 0; y < MatrixSize(matrix); y++) {
			MatrixRow * row = MatrixGet(matrix, y);
			for(x = 0; x < MatrixRowSize(row); x++) {
				MatrixField * field = MatrixRowGet(row, x);
				printf("[%s],", field->value);
			}
			printf("\n");
		}
	}
	return 0;
}
#endif
