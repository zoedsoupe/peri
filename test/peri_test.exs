defmodule PeriTest do
  use ExUnit.Case, async: true

  import Peri

  defschema(:simple, %{
    name: :string,
    age: :integer,
    email: {:required, :string}
  })

  defschema(:simple_mixed_keys, %{
    "email" => {:required, :string},
    name: :string,
    age: :integer
  })

  defschema(:nested, %{
    user: %{
      name: :string,
      profile: %{
        age: {:required, :integer},
        email: {:required, :string}
      }
    }
  })

  defschema(:optional_fields, %{
    name: :string,
    age: {:required, :integer},
    email: {:required, :string},
    phone: :string
  })

  defschema(:invalid_nested_type, %{
    user: %{
      name: :string,
      profile: %{
        age: {:required, :integer},
        email: :string,
        address: %{
          street: :string,
          number: :integer
        }
      }
    }
  })

  describe "simple schema validation" do
    test "validates simple schema with valid data" do
      data = %{name: "John", age: 30, email: "john@example.com"}
      assert {:ok, ^data} = simple(data)
    end

    test "validates simple schema with missing required field" do
      data = %{name: "John", age: 30}

      assert {:error,
              [%Peri.Error{path: [:email], message: "is required, expected type of :string"}]} =
               simple(data)
    end

    test "validates simple schema with invalid field type" do
      data = %{name: "John", age: "thirty", email: "john@example.com"}

      assert {
               :error,
               [
                 %Peri.Error{
                   path: [:age],
                   key: :age,
                   content: %{actual: "\"thirty\"", expected: :integer},
                   message: "expected type of :integer received \"thirty\" value",
                   errors: nil
                 }
               ]
             } =
               simple(data)
    end

    test "does not raise on simple schema with string keys" do
      data = %{name: "John", age: 30}

      assert {:error,
              [%Peri.Error{path: ["email"], message: "is required, expected type of :string"}]} =
               simple_mixed_keys(data)
    end
  end

  describe "nested schema validation" do
    test "validates nested schema with valid data" do
      data = %{user: %{name: "Jane", profile: %{age: 25, email: "jane@example.com"}}}
      assert {:ok, ^data} = nested(data)
    end

    test "validates nested schema with invalid data" do
      data = %{user: %{name: "Jane", profile: %{age: "twenty-five", email: "jane@example.com"}}}

      assert {
               :error,
               [
                 %Peri.Error{
                   message: nil,
                   path: [:user],
                   content: nil,
                   errors: [
                     %Peri.Error{
                       path: [:user, :profile],
                       key: :profile,
                       content: nil,
                       message: nil,
                       errors: [
                         %Peri.Error{
                           path: [:user, :profile, :age],
                           key: :age,
                           content: %{expected: :integer, actual: "\"twenty-five\""},
                           message: "expected type of :integer received \"twenty-five\" value",
                           errors: nil
                         }
                       ]
                     }
                   ],
                   key: :user
                 }
               ]
             } = nested(data)
    end

    test "validates nested schema with missing required field" do
      data = %{user: %{name: "Jane", profile: %{age: 25}}}

      assert {
               :error,
               [
                 %Peri.Error{
                   message: nil,
                   path: [:user],
                   content: nil,
                   errors: [
                     %Peri.Error{
                       path: [:user, :profile],
                       key: :profile,
                       content: nil,
                       message: nil,
                       errors: [
                         %Peri.Error{
                           path: [:user, :profile, :email],
                           key: :email,
                           content: %{expected: :string},
                           message: "is required, expected type of :string",
                           errors: nil
                         }
                       ]
                     }
                   ],
                   key: :user
                 }
               ]
             } =
               nested(data)
    end
  end

  describe "optional fields validation" do
    test "validates schema with optional fields" do
      data = %{name: "John", age: 30, email: "john@example.com"}
      assert {:ok, ^data} = optional_fields(data)

      data_with_optional = %{name: "John", age: 30, email: "john@example.com", phone: "123-456"}
      assert {:ok, ^data_with_optional} = optional_fields(data_with_optional)
    end

    test "validates schema with optional fields and invalid optional field type" do
      data = %{name: "John", age: 30, email: "john@example.com", phone: 123_456}

      assert {
               :error,
               [
                 %Peri.Error{
                   path: [:phone],
                   key: :phone,
                   content: %{actual: "123456", expected: :string},
                   message: "expected type of :string received 123456 value",
                   errors: nil
                 }
               ]
             } =
               optional_fields(data)
    end
  end

  defschema(:list_example, %{
    tags: {:list, :string},
    scores: {:list, :integer}
  })

  defschema(:enum_example, %{
    role: {:enum, [:admin, :user, :guest]},
    status: {:enum, [:active, :inactive]}
  })

  describe "list validation" do
    test "validates list of strings with correct data" do
      data = %{tags: ["elixir", "programming"], scores: [1, 2, 3]}
      assert list_example(data) == {:ok, data}
    end

    test "validates list of strings with incorrect data type in list" do
      data = %{tags: ["elixir", 42], scores: [1, 2, 3]}

      assert {
               :error,
               [
                 %Peri.Error{
                   path: [:tags],
                   key: :tags,
                   content: %{actual: "42", expected: :string},
                   message: "expected type of :string received 42 value",
                   errors: nil
                 }
               ]
             } =
               list_example(data)
    end

    test "validates list of integers with correct data" do
      data = %{tags: ["tag1", "tag2"], scores: [10, 20, 30]}
      assert list_example(data) == {:ok, data}
    end

    test "validates list of integers with incorrect data type in list" do
      data = %{tags: ["tag1", "tag2"], scores: [10, "twenty", 30]}

      assert {
               :error,
               [
                 %Peri.Error{
                   path: [:scores],
                   key: :scores,
                   content: %{actual: "\"twenty\"", expected: :integer},
                   message: "expected type of :integer received \"twenty\" value",
                   errors: nil
                 }
               ]
             } =
               list_example(data)
    end

    test "handles empty lists correctly" do
      data = %{tags: [], scores: []}
      assert list_example(data) == {:ok, data}
    end

    test "handles missing lists correctly" do
      data = %{}
      assert list_example(data) == {:ok, data}
    end
  end

  describe "enum validation" do
    test "validates enum with correct data" do
      data = %{role: :admin, status: :active}
      assert enum_example(data) == {:ok, data}
    end

    test "validates enum with incorrect data" do
      data = %{role: :superuser, status: :active}

      assert {:error,
              [
                %Peri.Error{
                  path: [:role],
                  message: "expected one of [:admin, :user, :guest] received :superuser"
                }
              ]} = enum_example(data)
    end

    test "validates enum with another incorrect data" do
      data = %{role: :admin, status: :pending}

      assert {:error,
              [
                %Peri.Error{
                  path: [:status],
                  message: "expected one of [:active, :inactive] received :pending"
                }
              ]} = enum_example(data)
    end

    test "handles missing enum fields correctly" do
      data = %{}
      assert enum_example(data) == {:ok, data}
    end

    test "handles nil enum fields correctly" do
      data = %{role: nil, status: nil}
      assert enum_example(data) == {:ok, data}
    end
  end

  defschema(:list_of_maps_example, %{
    users: {:list, %{name: {:required, :string}, age: {:required, :integer}}}
  })

  describe "list of maps validation" do
    test "validates list of maps with correct data" do
      data = %{users: [%{name: "Alice", age: 30}, %{name: "Bob", age: 25}]}
      assert list_of_maps_example(data) == {:ok, data}
    end

    test "validates list of maps with missing required fields" do
      data = %{users: [%{name: "Alice", age: 30}, %{age: 25}]}

      assert {
               :error,
               [
                 %Peri.Error{
                   message: nil,
                   path: [:users],
                   content: nil,
                   errors: [
                     %Peri.Error{
                       path: [:users, :name],
                       key: :name,
                       content: %{expected: :string},
                       message: "is required, expected type of :string",
                       errors: nil
                     }
                   ],
                   key: :users
                 }
               ]
             } =
               list_of_maps_example(data)
    end

    test "validates list of maps with incorrect field types" do
      data = %{users: [%{name: "Alice", age: "thirty"}, %{name: "Bob", age: 25}]}

      assert {
               :error,
               [
                 %Peri.Error{
                   message: nil,
                   path: [:users],
                   content: nil,
                   errors: [
                     %Peri.Error{
                       path: [:users, :age],
                       key: :age,
                       content: %{expected: :integer, actual: "\"thirty\""},
                       message: "expected type of :integer received \"thirty\" value",
                       errors: nil
                     }
                   ],
                   key: :users
                 }
               ]
             } =
               list_of_maps_example(data)
    end

    test "validates list of maps with extra fields" do
      data = %{users: [%{name: "Alice", age: 30, extra: "field"}, %{name: "Bob", age: 25}]}
      assert list_of_maps_example(data) == {:ok, data}
    end

    test "handles empty list of maps" do
      data = %{users: []}
      assert list_of_maps_example(data) == {:ok, data}
    end

    test "handles missing list of maps" do
      data = %{}
      assert list_of_maps_example(data) == {:ok, data}
    end
  end

  defmodule CustomValidations do
    def positive?(val) when is_integer(val) and val > 0, do: :ok
    def positive?(_val), do: {:error, "must be positive", []}

    def starts_with_a?(<<"a", _::binary>>), do: :ok
    def starts_with_a?(_val), do: {:error, "must start with %{prefix}", [prefix: "'a'"]}
  end

  defschema(:custom_example, %{
    positive_number: {:custom, &CustomValidations.positive?/1},
    name: {:custom, {CustomValidations, :starts_with_a?}}
  })

  defschema(:tuple_example, %{
    coordinates: {:tuple, [:float, :float]}
  })

  describe "custom validation" do
    test "validates custom validation functions with correct data" do
      data = %{positive_number: 5, name: "alice"}
      assert custom_example(data) == {:ok, data}
    end

    test "validates custom validation functions with incorrect data" do
      data = %{positive_number: -5, name: "bob"}

      assert {
               :error,
               [
                 %Peri.Error{
                   message: "must be positive",
                   path: [:positive_number],
                   content: %{},
                   errors: nil,
                   key: :positive_number
                 },
                 %Peri.Error{
                   message: "must start with 'a'",
                   path: [:name],
                   content: %{prefix: "'a'"},
                   errors: nil,
                   key: :name
                 }
               ]
             } = custom_example(data)
    end

    test "handles missing custom validation fields correctly" do
      data = %{}
      assert custom_example(data) == {:ok, data}
    end
  end

  describe "tuple validation" do
    test "validates tuple with correct data" do
      data = %{coordinates: {10.5, 20.5}}
      assert tuple_example(data) == {:ok, data}
    end

    test "validates tuple with incorrect data type" do
      data = %{coordinates: {10.5, "20.5"}}

      assert {
               :error,
               [
                 %Peri.Error{
                   message: "tuple element 1: expected type of :float received \"20.5\" value",
                   path: [:coordinates],
                   content: %{index: 1, expected: :float, actual: "\"20.5\""},
                   errors: nil,
                   key: :coordinates
                 }
               ]
             } = tuple_example(data)
    end

    test "validates tuple with incorrect size" do
      data = %{coordinates: {10.5}}

      assert {
               :error,
               [
                 %Peri.Error{
                   path: [:coordinates],
                   key: :coordinates,
                   content: %{length: 2, actual: 1},
                   message: "expected tuple of size 2 received tuple with 1 length",
                   errors: nil
                 }
               ]
             } = tuple_example(data)
    end

    test "validates tuple with extra elements" do
      data = %{coordinates: {10.5, 20.5, 30.5}}

      assert {
               :error,
               [
                 %Peri.Error{
                   path: [:coordinates],
                   key: :coordinates,
                   content: %{length: 2, actual: 3},
                   message: "expected tuple of size 2 received tuple with 3 length",
                   errors: nil
                 }
               ]
             } = tuple_example(data)
    end

    test "handles missing tuple correctly" do
      data = %{}
      assert tuple_example(data) == {:ok, data}
    end
  end

  defschema(:string_list, {:list, :string})
  defschema(:string_scores, %{name: :string, score: :float})
  defschema(:string_score_map, %{id: {:required, :integer}, scores: {:custom, &string_scores/1}})

  defschema(:recursive_schema, %{
    id: :integer,
    children: {:list, {:custom, &recursive_schema/1}}
  })

  describe "composable schema validation" do
    test "validates custom schema for list of strings" do
      data = ["hello", "world"]
      assert string_list(data) == {:ok, data}
    end

    test "validates custom schema for list of strings with invalid data" do
      data = ["hello", 123]

      assert {
               :error,
               %Peri.Error{
                 path: nil,
                 key: nil,
                 content: %{expected: :string, actual: "123"},
                 message: "expected type of :string received 123 value",
                 errors: nil
               }
             } =
               string_list(data)
    end

    test "validates custom schema for map with nested schema" do
      data = %{id: 1, scores: %{name: "test", score: 95.5}}
      assert string_score_map(data) == {:ok, data}
    end

    test "validates custom schema for map with nested schema with invalid data" do
      data = %{id: 1, scores: %{name: "test", score: "high"}}

      assert {
               :error,
               [
                 %Peri.Error{
                   message: nil,
                   path: [:scores],
                   content: nil,
                   errors: [
                     %Peri.Error{
                       path: [:scores, :score],
                       key: :score,
                       content: %{expected: :float, actual: "\"high\""},
                       message: "expected type of :float received \"high\" value",
                       errors: nil
                     }
                   ],
                   key: :scores
                 }
               ]
             } =
               string_score_map(data)
    end

    test "validates recursive schema with correct data" do
      data = %{
        id: 1,
        children: [%{id: 2, children: []}, %{id: 3, children: [%{id: 4, children: []}]}]
      }

      assert recursive_schema(data) == {:ok, data}
    end

    test "validates recursive schema with incorrect data" do
      data = %{id: 1, children: [%{id: 2, children: [%{id: "invalid", children: []}]}]}

      assert {
               :error,
               [
                 %Peri.Error{
                   message: nil,
                   path: [:children],
                   content: nil,
                   errors: [
                     %Peri.Error{
                       path: [:children, :children],
                       key: :children,
                       content: nil,
                       message: nil,
                       errors: [
                         %Peri.Error{
                           path: [:children, :children, :id],
                           key: :id,
                           content: %{expected: :integer, actual: "\"invalid\""},
                           message: "expected type of :integer received \"invalid\" value",
                           errors: nil
                         }
                       ]
                     }
                   ],
                   key: :children
                 }
               ]
             } = recursive_schema(data)
    end

    test "validates schema with missing required fields" do
      data = %{scores: %{name: "test", score: 95.5}}

      assert string_score_map(data) ==
               {
                 :error,
                 [
                   %Peri.Error{
                     content: %{expected: :integer},
                     errors: nil,
                     key: :id,
                     message: "is required, expected type of :integer",
                     path: [:id]
                   }
                 ]
               }
    end

    test "validates schema with extra fields" do
      data = %{id: 1, scores: %{name: "test", score: 95.5, extra: "field"}}
      expected = %{id: 1, scores: %{name: "test", score: 95.5}}

      assert {:ok, ^expected} = string_score_map(data)
    end
  end

  defschema(:user, %{
    name: :string,
    age: :integer,
    email: {:required, :string}
  })

  defschema(:profile, %{
    user: {:custom, &user/1},
    bio: :string
  })

  describe "unknown keys" do
    test "drops unknown keys and validates correct data" do
      data = %{name: "John", age: 30, email: "john@example.com", extra_key: "value"}
      expected_data = %{name: "John", age: 30, email: "john@example.com"}
      assert user(data) == {:ok, expected_data}
    end

    test "drops unknown keys and handles missing required field" do
      data = %{name: "John", age: 30, extra_key: "value"}

      assert user(data) == {
               :error,
               [
                 %Peri.Error{
                   content: %{expected: :string},
                   errors: nil,
                   key: :email,
                   message: "is required, expected type of :string",
                   path: [:email]
                 }
               ]
             }
    end

    test "drops multiple unknown keys and validates correct data" do
      data = %{
        name: "Jane",
        age: 25,
        email: "jane@example.com",
        extra_key1: "value1",
        extra_key2: "value2"
      }

      expected_data = %{name: "Jane", age: 25, email: "jane@example.com"}
      assert {:ok, ^expected_data} = user(data)
    end

    # test "drops nested unknown keys and validates correct data" do
    #   data = %{
    #     user: %{name: "John", age: 30, email: "john@example.com", extra_key: "value"},
    #     bio: "Developer",
    #     extra_key2: "value2"
    #   }

    #   expected_data = %{
    #     user: %{name: "John", age: 30, email: "john@example.com"},
    #     bio: "Developer"
    #   }

    #   assert {:ok, ^expected_data} = profile(data)
    # end

    test "drops nested unknown keys and handles missing required field" do
      data = %{
        user: %{name: "John", age: 30, extra_key: "value"},
        bio: "Developer",
        extra_key2: "value2"
      }

      assert profile(data) ==
               {:error,
                [
                  %Peri.Error{
                    content: nil,
                    errors: [
                      %Peri.Error{
                        path: [:user, :email],
                        key: :email,
                        content: %{expected: :string},
                        message: "is required, expected type of :string",
                        errors: nil
                      }
                    ],
                    key: :user,
                    message: nil,
                    path: [:user]
                  }
                ]}
    end
  end

  defschema(:simple_keyword, [
    {:name, :string},
    {:age, :integer},
    {:email, {:required, :string}}
  ])

  defschema(:nested_keyword, [
    {:user,
     [
       {:name, :string},
       {:profile,
        [
          {:age, {:required, :integer}},
          {:email, {:required, :string}}
        ]}
     ]}
  ])

  defschema(:optional_fields_keyword, [
    {:name, :string},
    {:age, {:required, :integer}},
    {:email, {:required, :string}},
    {:phone, :string}
  ])

  describe "simple keyword list schema validation" do
    test "validates simple keyword list schema with valid data" do
      data = [name: "John", age: 30, email: "john@example.com"]
      assert {:ok, ^data} = simple_keyword(data)
    end

    test "validates simple keyword list schema with missing required field" do
      data = [name: "John", age: 30]

      assert {:error,
              [%Peri.Error{path: [:email], message: "is required, expected type of :string"}]} =
               simple_keyword(data)
    end

    test "validates simple keyword list schema with invalid field type" do
      data = [name: "John", age: "thirty", email: "john@example.com"]

      assert {
               :error,
               [
                 %Peri.Error{
                   path: [:age],
                   key: :age,
                   content: %{actual: "\"thirty\"", expected: :integer},
                   message: "expected type of :integer received \"thirty\" value",
                   errors: nil
                 }
               ]
             } =
               simple_keyword(data)
    end
  end

  describe "nested keyword list schema validation" do
    test "validates nested keyword list schema with valid data" do
      data = [user: [name: "Jane", profile: [age: 25, email: "jane@example.com"]]]
      assert {:ok, ^data} = nested_keyword(data)
    end

    test "validates nested keyword list schema with invalid data" do
      data = [user: [name: "Jane", profile: [age: "twenty-five", email: "jane@example.com"]]]

      assert {
               :error,
               [
                 %Peri.Error{
                   message: nil,
                   path: [:user],
                   content: nil,
                   errors: [
                     %Peri.Error{
                       path: [:user, :profile],
                       key: :profile,
                       content: nil,
                       message: nil,
                       errors: [
                         %Peri.Error{
                           path: [:user, :profile, :age],
                           key: :age,
                           content: %{expected: :integer, actual: "\"twenty-five\""},
                           message: "expected type of :integer received \"twenty-five\" value",
                           errors: nil
                         }
                       ]
                     }
                   ],
                   key: :user
                 }
               ]
             } = nested_keyword(data)
    end

    test "validates nested keyword list schema with missing required field" do
      data = [user: [name: "Jane", profile: [age: 25]]]

      assert {
               :error,
               [
                 %Peri.Error{
                   message: nil,
                   path: [:user],
                   content: nil,
                   errors: [
                     %Peri.Error{
                       path: [:user, :profile],
                       key: :profile,
                       content: nil,
                       message: nil,
                       errors: [
                         %Peri.Error{
                           path: [:user, :profile, :email],
                           key: :email,
                           content: %{expected: :string},
                           message: "is required, expected type of :string",
                           errors: nil
                         }
                       ]
                     }
                   ],
                   key: :user
                 }
               ]
             } =
               nested_keyword(data)
    end
  end

  describe "optional fields keyword list validation" do
    test "validates keyword list schema with optional fields" do
      data = [name: "John", age: 30, email: "john@example.com"]
      assert {:ok, ^data} = optional_fields_keyword(data)

      data_with_optional = [name: "John", age: 30, email: "john@example.com", phone: "123-456"]
      assert {:ok, ^data_with_optional} = optional_fields_keyword(data_with_optional)
    end

    test "validates keyword list schema with optional fields and invalid optional field type" do
      data = [name: "John", age: 30, email: "john@example.com", phone: 123_456]

      assert {
               :error,
               [
                 %Peri.Error{
                   path: [:phone],
                   key: :phone,
                   content: %{actual: "123456", expected: :string},
                   message: "expected type of :string received 123456 value",
                   errors: nil
                 }
               ]
             } =
               optional_fields_keyword(data)
    end
  end

  defschema(:mixed_schema, %{
    user_info: [
      avatar: %{
        url: :string
      },
      username: {:required, :string},
      role: {:required, {:enum, [:admin, :user]}}
    ]
  })

  describe "mixed schema validation" do
    test "validates mixed schema with valid data" do
      data = %{
        user_info: [
          avatar: %{url: "http://example.com/avatar.jpg"},
          username: "john_doe",
          role: :admin
        ]
      }

      assert {:ok, ^data} = mixed_schema(data)
    end

    test "validates mixed schema with missing required field" do
      data = %{user_info: %{avatar: %{url: "http://example.com/avatar.jpg"}, role: :admin}}

      assert {
               :error,
               [
                 %Peri.Error{
                   message: nil,
                   path: [:user_info],
                   content: nil,
                   errors: [
                     %Peri.Error{
                       path: [:user_info, :username],
                       key: :username,
                       content: %{expected: :string},
                       message: "is required, expected type of :string",
                       errors: nil
                     }
                   ],
                   key: :user_info
                 }
               ]
             } =
               mixed_schema(data)
    end

    test "validates mixed schema with invalid enum value" do
      data = %{
        user_info: %{
          avatar: %{url: "http://example.com/avatar.jpg"},
          username: "john_doe",
          role: :superuser
        }
      }

      assert {
               :error,
               [
                 %Peri.Error{
                   message: nil,
                   path: [:user_info],
                   content: nil,
                   errors: [
                     %Peri.Error{
                       path: [:user_info, :role],
                       key: :role,
                       content: %{choices: "[:admin, :user]", actual: ":superuser"},
                       message: "expected one of [:admin, :user] received :superuser",
                       errors: nil
                     }
                   ],
                   key: :user_info
                 }
               ]
             } = mixed_schema(data)
    end

    test "validates mixed schema with invalid field type" do
      data = %{user_info: %{avatar: %{url: 12_345}, username: "john_doe", role: :admin}}

      assert {
               :error,
               [
                 %Peri.Error{
                   message: nil,
                   path: [:user_info],
                   content: nil,
                   errors: [
                     %Peri.Error{
                       path: [:user_info, :avatar],
                       key: :avatar,
                       content: nil,
                       message: nil,
                       errors: [
                         %Peri.Error{
                           path: [:user_info, :avatar, :url],
                           key: :url,
                           content: %{expected: :string, actual: "12345"},
                           message: "expected type of :string received 12345 value",
                           errors: nil
                         }
                       ]
                     }
                   ],
                   key: :user_info
                 }
               ]
             } = mixed_schema(data)
    end

    test "validates mixed schema with extra fields" do
      data = %{
        user_info: %{
          avatar: %{url: "http://example.com/avatar.jpg", size: "large"},
          username: "john_doe",
          role: :admin,
          extra_field: "extra"
        }
      }

      expected_data = %{
        user_info: [
          avatar: %{url: "http://example.com/avatar.jpg"},
          username: "john_doe",
          role: :admin
        ]
      }

      assert {:ok, ^expected_data} = mixed_schema(data)
    end
  end

  describe "validate_schema/1" do
    test "validates a correct schema" do
      schema = %{
        name: :string,
        age: :integer,
        email: {:required, :string},
        address: %{
          street: :string,
          city: :string
        },
        tags: {:list, :string},
        role: {:enum, [:admin, :user, :guest]},
        geolocation: {:tuple, [:float, :float]}
      }

      assert {:ok, ^schema} = Peri.validate_schema(schema)
    end

    test "detects an incorrect schema with invalid key" do
      schema = %{
        name: :str,
        age: :integer,
        email: {:required, :string}
      }

      assert {
               :error,
               [
                 %Peri.Error{
                   path: [:name],
                   key: :name,
                   content: %{
                     schema: %{name: :str, age: :integer, email: {:required, :string}},
                     invalid: ":str"
                   },
                   message: "invalid schema definition: :str",
                   errors: nil
                 }
               ]
             } =
               Peri.validate_schema(schema)
    end

    test "detects an incorrect schema with invalid nested key" do
      schema = %{
        address: %{
          street: :str,
          city: :string
        }
      }

      assert {
               :error,
               [
                 %Peri.Error{
                   path: [:address],
                   key: :address,
                   content: nil,
                   message: nil,
                   errors: [
                     %Peri.Error{
                       path: [:address, :street],
                       key: :street,
                       content: %{schema: %{street: :str, city: :string}, invalid: ":str"},
                       message: "invalid schema definition: :str",
                       errors: nil
                     }
                   ]
                 }
               ]
             } =
               Peri.validate_schema(schema)
    end

    test "detects an incorrect schema with invalid custom validation" do
      schema = %{
        custom_field: {:custom, "not_a_function"}
      }

      assert {:error,
              [
                %Peri.Error{
                  path: [:custom_field],
                  message: "invalid schema definition: {:custom, \"not_a_function\"}"
                }
              ]} =
               Peri.validate_schema(schema)
    end

    test "detects an incorrect schema with invalid either types" do
      schema = %{
        field: {:either, {:string, 123}}
      }

      assert {
               :error,
               [
                 %Peri.Error{
                   path: [:field],
                   key: :field,
                   content: %{schema: %{field: {:either, {:string, 123}}}, invalid: "123"},
                   message: "invalid schema definition: 123",
                   errors: nil
                 }
               ]
             } =
               Peri.validate_schema(schema)
    end

    test "detects an incorrect schema with invalid oneof types" do
      schema = %{
        field: {:oneof, [:string, 123]}
      }

      assert {
               :error,
               [
                 %Peri.Error{
                   path: [:field],
                   key: :field,
                   content: %{invalid: "123"},
                   message: "invalid schema definition: 123",
                   errors: nil
                 }
               ]
             } =
               Peri.validate_schema(schema)
    end

    test "detects an incorrect schema with invalid tuple types" do
      schema = %{
        geolocation: {:tuple, [:float, "string"]}
      }

      assert {
               :error,
               [
                 %Peri.Error{
                   path: [:geolocation],
                   key: :geolocation,
                   content: %{
                     schema: %{geolocation: {:tuple, [:float, "string"]}},
                     invalid: "\"string\""
                   },
                   message: "invalid schema definition: \"string\"",
                   errors: nil
                 }
               ]
             } =
               Peri.validate_schema(schema)
    end

    test "handles valid conditional types" do
      schema = %{
        conditional_field: {:cond, fn x -> x > 0 end, :integer, :string}
      }

      assert {:ok, ^schema} = Peri.validate_schema(schema)
    end

    test "handles valid dependent types" do
      schema = %{
        dependent_field: {:dependent, :string, fn _ -> true end, :integer}
      }

      assert {:ok, ^schema} = Peri.validate_schema(schema)
    end

    test "handles an empty schema" do
      schema = %{}

      assert {:ok, ^schema} = Peri.validate_schema(schema)
    end
  end

  defschema(:default_values, %{
    name: {:string, {:default, "Anonymous"}},
    age: {:integer, {:default, 0}},
    email: {:required, :string}
  })

  defschema(:nested_default_values, %{
    user: %{
      name: {:string, {:default, "John Doe"}},
      profile:
        {:required,
         %{
           email: {:string, {:default, "default@example.com"}},
           address:
             {:required,
              %{
                street: {:string, {:default, "123 Main St"}},
                number: {:integer, {:default, 1}}
              }}
         }}
    }
  })

  defschema(:invalid_nested_default_values, %{
    user: %{
      name: {:string, {:default, "John Doe"}},
      profile:
        {:required,
         %{
           age: {:required, :integer},
           email: {:required, {:string, {:default, "default@example.com"}}},
           address: %{
             street: {:string, {:default, "123 Main St"}},
             number: {:integer, {:default, 1}}
           }
         }}
    }
  })

  describe "default values schema validation" do
    test "applies default values when fields are missing" do
      data = %{email: "user@example.com"}
      expected_data = %{name: "Anonymous", age: 0, email: "user@example.com"}
      assert {:ok, ^expected_data} = default_values(data)
    end

    test "does not override provided values with defaults" do
      data = %{name: "Alice", age: 25, email: "alice@example.com"}
      assert {:ok, ^data} = default_values(data)
    end

    test "handles missing required fields" do
      data = %{name: "Alice", age: 25}

      assert {:error,
              [%Peri.Error{path: [:email], message: "is required, expected type of :string"}]} =
               default_values(data)
    end
  end

  describe "nested default values schema validation" do
    test "applies default values in nested schema" do
      data = %{user: %{profile: %{email: nil, address: %{number: nil, street: nil}}}}

      expected_data = %{
        user: %{
          name: "John Doe",
          profile: %{
            email: "default@example.com",
            address: %{street: "123 Main St", number: 1}
          }
        }
      }

      assert {:ok, ^expected_data} = nested_default_values(data)
    end

    test "does not override provided values in nested schema" do
      data = %{
        user: %{
          name: "Jane Doe",
          profile: %{
            email: "jane@example.com",
            address: %{street: "456 Elm St", number: 99}
          }
        }
      }

      assert {:ok, ^data} = nested_default_values(data)
    end

    test "required fields should not receive default values" do
      data = %{user: %{profile: %{age: 30}}}

      assert {
               :error,
               [
                 %Peri.Error{
                   path: [:user],
                   key: :user,
                   content: nil,
                   message: nil,
                   errors: [
                     %Peri.Error{
                       path: [:user, :profile],
                       key: :profile,
                       content: nil,
                       message: nil,
                       errors: [
                         %Peri.Error{
                           path: [:user, :profile, :email],
                           key: :email,
                           content: %{
                             type: :string,
                             value: "default@example.com",
                             schema: %{
                               address: %{
                                 number: {:integer, {:default, 1}},
                                 street: {:string, {:default, "123 Main St"}}
                               },
                               age: {:required, :integer},
                               email: {:required, {:string, {:default, "default@example.com"}}}
                             }
                           },
                           message:
                             "cannot set default value of default@example.com for required field of type :string",
                           errors: nil
                         }
                       ]
                     }
                   ]
                 }
               ]
             } = invalid_nested_default_values(data)
    end
  end

  defschema(:simple_list, [
    {:name, {:string, {:default, "Default Name"}}},
    {:age, {:integer, {:default, 18}}},
    {:email, {:required, :string}}
  ])

  defschema(
    :simple_tuple,
    {:tuple,
     [
       {:integer, {:default, 0}},
       {:string, {:default, "Unknown"}}
     ]}
  )

  describe "simple list schema validation" do
    test "applies default values for missing fields in keyword list schema" do
      data = [email: "user@example.com"]
      expected_data = [age: 18, name: "Default Name", email: "user@example.com"]
      assert {:ok, ^expected_data} = simple_list(data)
    end

    test "does not override provided values in keyword list schema" do
      data = [name: "Alice", age: 25, email: "alice@example.com"]
      assert {:ok, ^data} = simple_list(data)
    end
  end

  describe "simple tuple schema validation" do
    test "applies default values for missing elements in tuple schema" do
      data = {nil, nil}
      expected_data = {0, "Unknown"}
      assert {:ok, ^expected_data} = simple_tuple(data)
    end

    test "does not override provided values in tuple schema" do
      data = {42, "Provided"}
      assert {:ok, ^data} = simple_tuple(data)
    end
  end

  defp double(x), do: x * 2
  defp upcase(str), do: String.upcase(str)

  defschema(:basic_transform, %{
    number: {:integer, {:transform, &double/1}},
    name: {:string, {:transform, &upcase/1}}
  })

  defschema(:nested_transform, %{
    user: %{
      age: {:integer, {:transform, &double/1}},
      profile: %{
        nickname: {:string, {:transform, &upcase/1}}
      }
    }
  })

  defschema(:list_transform, %{
    scores: {:list, {:integer, {:transform, &double/1}}}
  })

  defschema(:dependent_transform, %{
    id: {:required, :string},
    name:
      {:string,
       {:transform,
        fn
          name, data -> (data[:id] && name <> "-#{data[:id]}") || name
        end}}
  })

  defschema(:nested_dependent_transform, %{
    user: %{
      birth_year: {:required, :integer},
      age: {:integer, {:transform, fn _, %{user: %{birth_year: y}} -> 2024 - y end}},
      profile: %{
        nickname:
          {:string,
           {:transform,
            fn nick, data ->
              year = get_in(data, [:user, :birth_year])
              if year > 2006, do: nick, else: "doomed"
            end}}
      }
    }
  })

  describe "basic transform schema" do
    test "applies transform function correctly" do
      data = %{number: 5, name: "john"}
      expected = %{number: 10, name: "JOHN"}
      assert {:ok, ^expected} = basic_transform(data)
    end
  end

  describe "nested transform schema" do
    test "applies transform function correctly in nested schema" do
      data = %{user: %{age: 5, profile: %{nickname: "john"}}}
      expected = %{user: %{age: 10, profile: %{nickname: "JOHN"}}}
      assert {:ok, ^expected} = nested_transform(data)
    end
  end

  describe "list transform schema" do
    test "applies transform function correctly in list schema" do
      data = %{scores: [1, 2, 3]}
      expected = %{scores: [2, 4, 6]}
      assert {:ok, ^expected} = list_transform(data)
    end
  end

  describe "dependent fields transform" do
    test "applies transform function correctly with dependent fields" do
      data = %{id: "123", name: "john"}
      expected = %{id: "123", name: "john-123"}
      assert {:ok, ^expected} = dependent_transform(data)

      # how about keyword lists?
      data = [id: "123", name: "maria"]
      s = Map.to_list(get_schema(:dependent_transform))
      assert {:ok, valid} = Peri.validate(s, data)
      assert valid[:id] == "123"
      assert valid[:name] == "maria-123"

      # order shouldn't matter too
      data = [name: "maria", id: "123"]
      s = Map.to_list(get_schema(:dependent_transform))
      assert {:ok, valid} = Peri.validate(s, data)
      assert valid[:id] == "123"
      assert valid[:name] == "maria-123"
    end

    test "it should return an error if the dependent field is invalid" do
      data = %{id: 123, name: "john"}

      assert {
               :error,
               [
                 %Peri.Error{
                   path: [:id],
                   key: :id,
                   content: %{actual: "123", expected: :string},
                   message: "expected type of :string received 123 value",
                   errors: nil
                 }
               ]
             } = dependent_transform(data)

      # map order shouldn't matter
      data = %{name: "john", id: 123}

      assert {:error,
              [
                %Peri.Error{
                  path: [:id],
                  key: :id,
                  content: %{actual: "123", expected: :string},
                  message: "expected type of :string received 123 value",
                  errors: nil
                }
              ]} = dependent_transform(data)
    end

    test "it should support nested dependent transformations too" do
      data = %{user: %{birth_year: 2007, age: 5, profile: %{nickname: "john"}}}
      expected = %{user: %{birth_year: 2007, age: 17, profile: %{nickname: "john"}}}
      assert {:ok, ^expected} = nested_dependent_transform(data)
    end
  end

  describe "transform with MFA" do
    test "it should apply the mapper function without additional argument" do
      s = {:string, {:transform, {String, :to_integer}}}
      assert {:ok, 10} = Peri.validate(s, "10")
    end

    test "it should apply the mapper function without additional argument but with dependent field" do
      s = %{id: {:string, {:transform, {__MODULE__, :integer_by_name}}}, name: :string}
      data = %{id: "10", name: "john"}
      assert {:ok, %{id: 20, name: "john"}} = Peri.validate(s, data)

      data = %{id: "10", name: "maria"}
      assert {:ok, %{id: 10, name: "maria"}} = Peri.validate(s, data)
    end

    test "it should apply mapper function with additional arguments" do
      s = {:string, {:transform, {String, :split, [~r/\D/, [trim: true]]}}}
      assert {:ok, ["10"]} = Peri.validate(s, "omw 10")
    end

    test "it should apply mapper function with additional arguments with dependent field" do
      s = %{
        id: {:string, {:transform, {__MODULE__, :integer_by_name, [[make_sense?: false]]}}},
        name: :string
      }

      data = %{id: "10", name: "john"}
      assert {:ok, %{id: 10, name: "john"}} = Peri.validate(s, data)
    end
  end

  def integer_by_name(id, %{name: name}) do
    if name != "john" do
      String.to_integer(id)
    else
      String.to_integer(id) + 10
    end
  end

  def integer_by_name(id, %{name: name}, make_sense?: sense) do
    cond do
      sense && name != "john" -> String.to_integer(id) - 10
      not sense && name == "john" -> String.to_integer(id)
      true -> 42
    end
  end

  defschema(:either_transform, %{
    value: {:either, {{:integer, {:transform, &double/1}}, {:string, {:transform, &upcase/1}}}}
  })

  defschema(:either_transform_mixed, %{
    value: {:either, {{:integer, {:transform, &double/1}}, :string}}
  })

  defschema(:oneof_transform, %{
    value: {:oneof, [{:integer, {:transform, &double/1}}, {:string, {:transform, &upcase/1}}]}
  })

  describe "either transform schema" do
    test "applies transform function correctly for integer type" do
      data = %{value: 5}
      expected = %{value: 10}
      assert {:ok, ^expected} = either_transform(data)
    end

    test "applies transform function correctly for string type" do
      data = %{value: "john"}
      expected = %{value: "JOHN"}
      assert {:ok, ^expected} = either_transform(data)
    end
  end

  describe "either transform mixed schema" do
    test "applies transform function correctly for integer type" do
      data = %{value: 5}
      expected = %{value: 10}
      assert {:ok, ^expected} = either_transform_mixed(data)
    end

    test "applies transform function correctly for string type" do
      data = %{value: "john"}
      assert {:ok, ^data} = either_transform_mixed(data)
    end
  end

  describe "oneof transform schema" do
    test "applies transform function correctly for integer type" do
      data = %{value: 5}
      expected = %{value: 10}
      assert {:ok, ^expected} = oneof_transform(data)
    end

    test "applies transform function correctly for string type" do
      data = %{value: "john"}
      expected = %{value: "JOHN"}
      assert {:ok, ^expected} = oneof_transform(data)
    end
  end

  defschema(:mixed, %{
    id: {:integer, {:transform, &(&1 * 2)}},
    name:
      {:either,
       {{:string, {:transform, &String.upcase/1}}, {:atom, {:transform, &Atom.to_string/1}}}},
    tags: {:list, :string},
    info:
      {:oneof,
       [
         {:string, {:transform, &String.upcase/1}},
         %{
           age: {:integer, {:transform, &(&1 + 1)}},
           address: %{
             street: :string,
             number: :integer
           }
         }
       ]}
  })

  describe "massive mixed schema validation" do
    test "validates and transforms mixed schema with integer id and string info" do
      data = %{id: 5, name: :john, tags: ["elixir", "programming"], info: "some info"}

      expected = %{
        id: 10,
        name: "john",
        tags: ["elixir", "programming"],
        info: "SOME INFO"
      }

      assert {:ok, ^expected} = mixed(data)
    end

    test "validates and transforms mixed schema with integer id and map info" do
      data = %{
        id: 7,
        name: "jane",
        tags: ["elixir", "programming"],
        info: %{age: 25, address: %{street: "Main St", number: 123}}
      }

      expected = %{
        id: 14,
        name: "JANE",
        tags: ["elixir", "programming"],
        info: %{age: 26, address: %{street: "Main St", number: 123}}
      }

      assert {:ok, ^expected} = mixed(data)
    end

    test "validates and transforms mixed schema with atom name" do
      data = %{id: 8, name: :doe, tags: ["elixir"], info: "details"}

      expected = %{
        id: 16,
        name: "doe",
        tags: ["elixir"],
        info: "DETAILS"
      }

      assert {:ok, ^expected} = mixed(data)
    end

    test "returns error for invalid info type in mixed schema" do
      data = %{id: 8, name: "doe", tags: ["elixir"], info: 123}
      assert {:error, errors} = mixed(data)
      assert [%Peri.Error{path: [:info], message: _}] = errors
    end
  end

  defschema(:regex_validation, %{
    username: {:string, {:regex, ~r/^[a-zA-Z0-9_]+$/}}
  })

  defschema(:string_eq_validation, %{
    exact_name: {:string, {:eq, "Elixir"}}
  })

  defschema(:string_min_validation, %{
    short_text: {:string, {:min, 5}}
  })

  defschema(:string_max_validation, %{
    long_text: {:string, {:max, 20}}
  })

  defschema(:numeric_eq_validation, %{
    exact_number: {:integer, {:eq, 42}}
  })

  defschema(:numeric_neq_validation, %{
    not_this_number: {:integer, {:neq, 42}}
  })

  defschema(:numeric_gt_validation, %{
    greater_than: {:integer, {:gt, 10}}
  })

  defschema(:numeric_gte_validation, %{
    greater_than_or_equal: {:integer, {:gte, 10}}
  })

  defschema(:numeric_lt_validation, %{
    less_than: {:integer, {:lt, 10}}
  })

  defschema(:numeric_lte_validation, %{
    less_than_or_equal: {:integer, {:lte, 10}}
  })

  defschema(:numeric_range_validation, %{
    in_range: {:integer, {:range, {5, 15}}}
  })

  describe "regex validation" do
    test "validates a string against a regex pattern" do
      assert {:ok, %{username: "valid_user"}} = regex_validation(%{username: "valid_user"})

      assert {:error, [%Peri.Error{message: "should match the ~r/^[a-zA-Z0-9_]+$/ pattern"}]} =
               regex_validation(%{username: "invalid user"})
    end
  end

  describe "string equal validation" do
    test "validates a string to be exactly equal to a value" do
      assert {:ok, %{exact_name: "Elixir"}} = string_eq_validation(%{exact_name: "Elixir"})

      assert {:error, [%Peri.Error{message: "should be equal to literal Elixir"}]} =
               string_eq_validation(%{exact_name: "Phoenix"})
    end
  end

  describe "string minimum length validation" do
    test "validates a string to have a minimum length" do
      assert {:ok, %{short_text: "Hello"}} = string_min_validation(%{short_text: "Hello"})

      assert {:error, [%Peri.Error{message: "should have the minimum length of 5"}]} =
               string_min_validation(%{short_text: "Hi"})
    end
  end

  describe "string maximum length validation" do
    test "validates a string to have a maximum length" do
      assert {:ok, %{long_text: "This is a test"}} =
               string_max_validation(%{long_text: "This is a test"})

      assert {:error, [%Peri.Error{message: "should have the maximum length of 20"}]} =
               string_max_validation(%{long_text: "This text is too long for validation"})
    end
  end

  describe "numeric equal validation" do
    test "validates a number to be exactly equal to a value" do
      assert {:ok, %{exact_number: 42}} = numeric_eq_validation(%{exact_number: 42})

      assert {:error, [%Peri.Error{message: "should be equal to 42"}]} =
               numeric_eq_validation(%{exact_number: 43})
    end
  end

  describe "numeric not equal validation" do
    test "validates a number to not be equal to a value" do
      assert {:ok, %{not_this_number: 43}} = numeric_neq_validation(%{not_this_number: 43})

      assert {:error, [%Peri.Error{message: "should be not equal to 42"}]} =
               numeric_neq_validation(%{not_this_number: 42})
    end
  end

  describe "numeric greater than validation" do
    test "validates a number to be greater than a value" do
      assert {:ok, %{greater_than: 11}} = numeric_gt_validation(%{greater_than: 11})

      assert {:error, [%Peri.Error{message: "should be greater then 10"}]} =
               numeric_gt_validation(%{greater_than: 10})
    end
  end

  describe "numeric greater than or equal validation" do
    test "validates a number to be greater than or equal to a value" do
      assert {:ok, %{greater_than_or_equal: 10}} =
               numeric_gte_validation(%{greater_than_or_equal: 10})

      assert {:error, [%Peri.Error{message: "should be greater then or equal to 10"}]} =
               numeric_gte_validation(%{greater_than_or_equal: 9})
    end
  end

  describe "numeric less than validation" do
    test "validates a number to be less than a value" do
      assert {:ok, %{less_than: 9}} = numeric_lt_validation(%{less_than: 9})

      assert {:error, [%Peri.Error{message: "should be less then 10"}]} =
               numeric_lt_validation(%{less_than: 10})
    end
  end

  describe "numeric less than or equal validation" do
    test "validates a number to be less than or equal to a value" do
      assert {:ok, %{less_than_or_equal: 10}} = numeric_lte_validation(%{less_than_or_equal: 10})

      assert {:error, [%Peri.Error{message: "should be less then or equal to 10"}]} =
               numeric_lte_validation(%{less_than_or_equal: 11})
    end
  end

  describe "numeric range validation" do
    test "validates a number to be within a range" do
      assert {:ok, %{in_range: 10}} = numeric_range_validation(%{in_range: 10})

      assert {:error, [%Peri.Error{message: "should be in the range of 5..15 (inclusive)"}]} =
               numeric_range_validation(%{in_range: 4})

      assert {:error, [%Peri.Error{message: "should be in the range of 5..15 (inclusive)"}]} =
               numeric_range_validation(%{in_range: 16})
    end
  end

  defmodule TypeDependentSchema do
    import Peri

    defschema(:email_details, %{email: {:required, :string}})
    defschema(:country_details, %{country: {:required, :string}})
    defschema(:details, Map.merge(get_schema(:email_details), get_schema(:country_details)))

    defschema(:info, %{
      name: {:required, :string},
      provide_email: {:required, :boolean},
      provide_country: {:required, :boolean},
      details: {:dependent, &verify_details/1}
    })

    defp verify_details(data) do
      %{provide_email: pe, provide_country: pc} = data

      provide = {pe, pc}

      case provide do
        {true, true} -> {:ok, {:required, get_schema(:details)}}
        {true, false} -> {:ok, {:required, get_schema(:email_details)}}
        {false, true} -> {:ok, {:required, get_schema(:country_details)}}
        {false, false} -> {:ok, nil}
      end
    end
  end

  describe "TypeDependentSchema.info/1" do
    test "validates correctly when both email and country are provided" do
      data = %{
        name: "John Doe",
        provide_email: true,
        provide_country: true,
        details: %{
          email: "john@example.com",
          country: "USA"
        }
      }

      assert {:ok, valid_data} = TypeDependentSchema.info(data)
      assert valid_data == data
    end

    test "validates correctly when only email is provided" do
      data = %{
        name: "Jane Doe",
        provide_email: true,
        provide_country: false,
        details: %{
          email: "jane@example.com"
        }
      }

      assert {:ok, valid_data} = TypeDependentSchema.info(data)
      assert valid_data == data
    end

    test "validates correctly when only country is provided" do
      data = %{
        name: "Jake Doe",
        provide_email: false,
        provide_country: true,
        details: %{country: "Canada"}
      }

      assert {:ok, valid_data} = TypeDependentSchema.info(data)
      assert valid_data == data
    end

    test "validates correctly when neither email nor country is provided" do
      data = %{name: "Jenny Doe", provide_email: false, provide_country: false}

      assert {:ok, valid_data} = TypeDependentSchema.info(data)
      assert valid_data == data
    end

    test "returns an error when email is required but not provided" do
      data = %{name: "John Doe", provide_email: true, provide_country: false}

      assert {
               :error,
               [
                 %Peri.Error{
                   path: [:details],
                   key: :details,
                   content: %{expected: %{email: {:required, :string}}},
                   message: "is required, expected type of %{email: {:required, :string}}",
                   errors: nil
                 }
               ]
             } =
               TypeDependentSchema.info(data)
    end

    test "returns an error when country is required but not provided" do
      data = %{name: "John Doe", provide_email: false, provide_country: true}

      assert {
               :error,
               [
                 %Peri.Error{
                   path: [:details],
                   key: :details,
                   content: %{expected: %{country: {:required, :string}}},
                   message: "is required, expected type of %{country: {:required, :string}}",
                   errors: nil
                 }
               ]
             } =
               TypeDependentSchema.info(data)
    end
  end

  defmodule CondSchema do
    import Peri

    defschema(:details, %{
      email: {:required, :string},
      country: {:required, :string}
    })

    defschema(:info, %{
      name: {:required, :string},
      provide_details: {:required, :boolean},
      details: {:cond, & &1.provide_details, {:required, get_schema(:details)}, nil}
    })
  end

  describe "CondSchema.info/1" do
    test "validates correctly when provide_details is true" do
      data = %{
        name: "John Doe",
        provide_details: true,
        details: %{email: "john@example.com", country: "USA"}
      }

      assert {:ok, valid_data} = CondSchema.info(data)

      assert valid_data == data
    end

    test "validates correctly when provide_details is false" do
      data = %{name: "Jane Doe", provide_details: false}

      assert {:ok, valid_data} = CondSchema.info(data)
      assert valid_data == data
    end

    test "returns error when provide_details is true but details are missing" do
      data = %{name: "John Doe", provide_details: true}

      assert {:error, errors} = CondSchema.info(data)
      assert length(errors) == 1

      assert [
               %Peri.Error{
                 path: [:details],
                 key: :details,
                 content: %{
                   expected: %{email: {:required, :string}, country: {:required, :string}}
                 },
                 message:
                   "is required, expected type of %{email: {:required, :string}, country: {:required, :string}}",
                 errors: nil
               }
             ] = errors
    end

    test "returns error when provide_details is true but only partial details are provided" do
      data = %{
        name: "John Doe",
        provide_details: true,
        details: %{email: "john@example.com"}
      }

      assert {:error, errors} = CondSchema.info(data)

      assert [
               %Peri.Error{
                 path: [:details],
                 key: :details,
                 content: nil,
                 message: nil,
                 errors: [
                   %Peri.Error{
                     path: [:details, :country],
                     key: :country,
                     content: %{expected: :string},
                     message: "is required, expected type of :string",
                     errors: nil
                   }
                 ]
               }
             ] = errors
    end
  end

  defmodule User do
    defstruct [:name, :age, :email]
  end

  defschema(:user_map_schema, %{
    name: {:required, :string},
    age: :integer,
    email: {:required, :string}
  })

  describe "basic struct input validation" do
    test "validates struct input with valid data" do
      data = %User{name: "John", age: 30, email: "john@example.com"}
      assert {:ok, ^data} = user_map_schema(data)
    end

    test "validates struct input with missing required field" do
      data = %User{name: "John", age: 30}

      assert {:error,
              [%Peri.Error{path: [:email], message: "is required, expected type of :string"}]} =
               user_map_schema(data)
    end

    test "validates struct input with invalid field type" do
      data = %User{name: "John", age: "thirty", email: "john@example.com"}

      assert {:error,
              [
                %Peri.Error{
                  path: [:age],
                  message: "expected type of :integer received \"thirty\" value"
                }
              ]} = user_map_schema(data)
    end
  end

  defschema(:cond_with_nest_default, %{
    name: {:required, :string},
    provide_details: {:required, :boolean},
    details: {:cond, & &1.provide_details, get_schema(:details), nil}
  })

  defschema(:details, %{
    email: {:string, {:default, "foo@example.com"}},
    country: {:string, {:default, "USA"}}
  })

  describe "default values with conditional schema" do
    test "validates correctly when provide_details is true" do
      data = %{
        name: "John Doe",
        provide_details: true
      }

      assert {:ok, valid_data} = cond_with_nest_default(data)

      assert valid_data == %{
               name: "John Doe",
               provide_details: true,
               details: %{email: "foo@example.com", country: "USA"}
             }
    end

    test "validates correctly when provide_details is false" do
      data = %{
        name: "Jane Doe",
        provide_details: false
      }

      assert {:ok, valid_data} = cond_with_nest_default(data)

      assert valid_data == %{
               name: "Jane Doe",
               provide_details: false
             }
    end

    test "validates correctly when provide_details is true and details are provided" do
      data = %{
        name: "John Doe",
        provide_details: true,
        details: %{email: "zoey@example.com", country: "Canada"}
      }

      assert {:ok, valid_data} = cond_with_nest_default(data)

      assert valid_data == %{
               name: "John Doe",
               provide_details: true,
               details: %{email: "zoey@example.com", country: "Canada"}
             }
    end
  end
end
