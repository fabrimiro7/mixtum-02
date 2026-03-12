from django.test import TestCase
from rest_framework.test import APIClient


class ExampleModelListViewTest(TestCase):

    def setUp(self):
        self.client = APIClient()

    def test_list_requires_authentication(self):
        pass

    def test_list_returns_200(self):
        pass

    def test_create_returns_201(self):
        pass

    def test_create_returns_400_with_invalid_data(self):
        pass


class ExampleModelDetailViewTest(TestCase):

    def setUp(self):
        self.client = APIClient()

    def test_detail_requires_authentication(self):
        pass

    def test_detail_returns_200(self):
        pass

    def test_detail_returns_404_if_not_found(self):
        pass

    def test_patch_returns_200(self):
        pass

    def test_delete_returns_204(self):
        pass
