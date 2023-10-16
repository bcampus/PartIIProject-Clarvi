#define SORT_SIZE 100

int arr[SORT_SIZE];

void initArray(){
    for (int i = 0; i < SORT_SIZE; i++){
        arr[i] = SORT_SIZE - i;
    }
}

void bubbleSort(){
    char sorted = 0;
    int count = 0;
    while (!sorted) {
        sorted = 1;
        for (int i = 1; i < SORT_SIZE - count; i++){
            if (arr[i-1] <= arr[i]) continue;
            sorted = 0;
            int tmp = arr[i-1];
            arr[i-1]=arr[i];
            arr[i] = tmp;
        }
        count++;
    }
}

void bubbleSortBenchMark(){
    initArray();
    bubbleSort();
}
