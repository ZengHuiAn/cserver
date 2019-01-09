#ifndef _MATRIX_H_
#define _MATRIX_H_

#include <stdlib.h>

typedef struct Matrix Matrix;
typedef struct MatrixRow MatrixRow;
typedef struct MatrixField MatrixField;

Matrix * LoadMatrix(const char * filename,
		char sep_field /*= ','*/, char sep_row/* = '\n'*/);
void MatrixFree(Matrix * matrix);

size_t MatrixSize(Matrix * matrix);
MatrixRow * MatrixGet(Matrix * matrix, size_t row);

size_t MatrixRowSize(MatrixRow * row);
MatrixField * MatrixRowGet(MatrixRow * row, size_t field);

const char * MatrixFieldValue(MatrixField * field);

#endif
